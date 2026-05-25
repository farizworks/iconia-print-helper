import 'dart:async';
import 'dart:io';

import 'package:iconia_print_helper/config.dart';
import 'package:iconia_print_helper/esc_pos_generator.dart';
import 'package:iconia_print_helper/firestore_client.dart';
import 'package:iconia_print_helper/job_processor.dart';
import 'package:iconia_print_helper/template_renderer.dart';

Future<void> main(List<String> args) async {
  // arabic-test mode: send an Arabic test page directly to the first printer.
  if (args.contains('--arabic-test')) {
    final configPath = args.firstWhere(
      (a) => !a.startsWith('-'),
      orElse: () => 'config.json',
    );
    await _runArabicTest(configPath);
    return;
  }

  final configPath = args.isNotEmpty ? args.first : 'config.json';
  final config = await HelperConfig.load(configPath);
  _validate(config);

  final firestore = FirestoreClient(config);
  await firestore.initialize();

  final processor = JobProcessor(
    config: config,
    firestore: firestore,
    renderer: TemplateRenderer(),
  );

  final signals = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen((_) => processor.requestStop()),
    if (!Platform.isWindows)
      ProcessSignal.sigterm.watch().listen((_) => processor.requestStop()),
  ];

  try {
    await processor.run();
  } finally {
    for (final sub in signals) {
      await sub.cancel();
    }
  }
}

Future<void> _runArabicTest(String configPath) async {
  final config = await HelperConfig.load(configPath);
  if (config.printers.isEmpty) {
    stderr.writeln('No printers in config.');
    exit(1);
  }
  final printer = config.printers.first;
  final host = printer.host;
  if (printer.backend != 'network' || host == null || host.isEmpty) {
    stderr.writeln('Arabic test only works with network backend printers.');
    exit(1);
  }
  final bytes = EscPosGenerator.buildArabicTest(80);

  stdout.writeln(
    '[arabic-test] Sending ${bytes.length} bytes to $host:${printer.port} ...',
  );
  final socket = await Socket.connect(
    host,
    printer.port,
    timeout: const Duration(seconds: 10),
  );
  socket.add(bytes);
  await socket.flush();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await socket.close();
  stdout.writeln('[arabic-test] Done. Check your printer output.');
}

void _validate(HelperConfig config) {
  if (config.firebase.projectId.isEmpty ||
      config.firebase.apiKey.isEmpty ||
      config.firebase.email.isEmpty ||
      config.firebase.password.isEmpty) {
    throw Exception('Firebase config is incomplete.');
  }
  if (config.restaurantId.isEmpty) {
    throw Exception('restaurantId is required.');
  }
}
