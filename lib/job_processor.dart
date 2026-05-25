import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'firestore_client.dart';
import 'printer_backends/fake_printer.dart';
import 'printer_backends/network_printer.dart';
import 'printer_backends/printer_backend.dart';
import 'template_renderer.dart';

class JobProcessor {
  final HelperConfig config;
  final FirestoreClient firestore;
  final TemplateRenderer renderer;
  bool _stopRequested = false;
  bool _processing = false;
  DateTime? _lastHeartbeatAt;
  DateTime? _lastHealthCheckAt;
  DateTime? _lastPrinterSyncAt;
  List<PrinterConfig> _availablePrinters = const [];

  JobProcessor({
    required this.config,
    required this.firestore,
    required this.renderer,
  });

  void requestStop() {
    _log('Stop requested. Waiting for current job to finish...');
    _stopRequested = true;
  }

  Future<void> run() async {
    _log('Helper started');
    _log('Listening for jobs for restaurant ${config.restaurantId}');
    await _syncPrintersIfDue(force: true);
    while (!_stopRequested) {
      await _publishHealthIfDue();
      if (_processing) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }
      final jobs = await firestore.pendingJobs();
      if (jobs.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      for (final job in jobs) {
        if (_stopRequested) break;
        await _process(job);
      }
    }
    _log('Helper stopped');
  }

  Future<void> _publishHealthIfDue() async {
    final now = DateTime.now();
    final heartbeatDue =
        _lastHeartbeatAt == null ||
        now.difference(_lastHeartbeatAt!) >= const Duration(seconds: 15);
    final healthCheckDue =
        _lastHealthCheckAt == null ||
        now.difference(_lastHealthCheckAt!) >= const Duration(seconds: 30);

    if (!heartbeatDue && !healthCheckDue) return;

    try {
      await _syncPrintersIfDue(force: healthCheckDue);
      if (heartbeatDue) {
        await firestore.writeHeartbeat(
          printerCount: _configuredPrinters.length,
        );
        _lastHeartbeatAt = now;
      }
      if (healthCheckDue) {
        await _checkPrinters();
        _lastHealthCheckAt = now;
      }
    } catch (e) {
      _log('Health update failed: $e');
    }
  }

  Future<void> _syncPrintersIfDue({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastPrinterSyncAt != null &&
        now.difference(_lastPrinterSyncAt!) < const Duration(seconds: 30)) {
      return;
    }

    try {
      final remotePrinters = await firestore.networkPrinters();
      final merged = <String, PrinterConfig>{
        for (final printer in config.printers) printer.id: printer,
        for (final printer in remotePrinters) printer.id: printer,
      };
      _availablePrinters = merged.values.toList();
      _lastPrinterSyncAt = now;
      _log(
        'Loaded ${remotePrinters.length} active network printer(s) from '
        'Firestore; ${_availablePrinters.length} available on helper',
      );
    } catch (e) {
      if (_availablePrinters.isEmpty) {
        _availablePrinters = List<PrinterConfig>.from(config.printers);
      }
      _log('Could not refresh printers from Firestore: $e');
    }
  }

  List<PrinterConfig> get _configuredPrinters =>
      _availablePrinters.isEmpty ? config.printers : _availablePrinters;

  PrinterConfig? _printerById(String id) {
    for (final printer in _configuredPrinters) {
      if (printer.id == id) return printer;
    }
    return null;
  }

  Future<void> _checkPrinters() async {
    for (final printer in _configuredPrinters) {
      if (_stopRequested) return;
      Object? error;
      var reachable = false;
      try {
        await _checkPrinter(printer);
        reachable = true;
      } catch (e) {
        error = e;
      }
      await firestore.writePrinterStatus(
        printer: printer,
        isReachable: reachable,
        error: error,
      );
      _log(
        'Printer ${printer.name} (${printer.id}) '
        '${reachable ? 'online' : 'offline: $error'}',
      );
    }
  }

  Future<void> _checkPrinter(PrinterConfig printer) async {
    if (printer.backend == 'fake') return;
    if (printer.backend != 'network') {
      throw Exception(
        'Health check unsupported for backend ${printer.backend}',
      );
    }
    final host = printer.host;
    if (host == null || host.isEmpty) {
      throw Exception('Network printer host is missing');
    }
    final socket = await Socket.connect(
      host,
      printer.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
  }

  Future<void> _process(PrintJob job) async {
    _processing = true;
    _log('Processing job ${job.id} (${job.type})');
    try {
      await firestore.markPrinting(job);
      var printer = _printerById(job.printerId);
      if (printer == null) {
        await _syncPrintersIfDue(force: true);
        printer = _printerById(job.printerId);
      }
      if (printer == null) {
        throw Exception(
          'Printer is not an active network printer in Firestore or a '
          'local test printer: ${job.printerId}',
        );
      }
      final bytes = renderer.render(job);
      _log('Generated ${bytes.length} bytes for printer ${printer.name}');
      _log('Logical print preview for job ${job.id}:');
      stdout.writeln('----- PRINT PREVIEW START -----');
      stdout.writeln(renderer.debugPreview(job));
      stdout.writeln('----- PRINT PREVIEW END -------');
      stdout.writeln(
        '[Arabic mode] ESC t 21 / PC1001; logical RTL text sent without software reversal.',
      );
      await _backend(
        printer,
      ).printBytes(printer: printer, job: job, bytes: bytes);
      await firestore.markPrinted(job);
      _log('Job ${job.id} marked printed');
    } catch (e) {
      _log('Job ${job.id} failed: $e');
      await firestore.markFailedOrRetry(job, e);
    } finally {
      _processing = false;
    }
  }

  PrinterBackend _backend(PrinterConfig printer) {
    return switch (printer.backend) {
      'network' => NetworkPrinter(),
      _ => FakePrinter(),
    };
  }

  void _log(String message) {
    print('[${DateTime.now().toIso8601String()}] $message');
  }
}
