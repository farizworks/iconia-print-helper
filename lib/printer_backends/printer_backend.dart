import 'dart:typed_data';

import '../config.dart';
import '../template_renderer.dart';

abstract class PrinterBackend {
  Future<void> printBytes({
    required PrinterConfig printer,
    required PrintJob job,
    required Uint8List bytes,
  });
}
