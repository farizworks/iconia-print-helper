import 'dart:io';
import 'dart:typed_data';

import '../config.dart';
import '../template_renderer.dart';
import 'printer_backend.dart';

class NetworkPrinter implements PrinterBackend {
  @override
  Future<void> printBytes({
    required PrinterConfig printer,
    required PrintJob job,
    required Uint8List bytes,
  }) async {
    final host = printer.host;
    if (host == null || host.isEmpty) {
      throw Exception('Network printer host is missing');
    }
    final socket = await Socket.connect(
      host,
      printer.port,
      timeout: const Duration(seconds: 10),
    );
    socket.add(bytes);
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await socket.close();
  }
}
