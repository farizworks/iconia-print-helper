import 'dart:io';
import 'dart:typed_data';

import '../config.dart';
import '../template_renderer.dart';
import 'printer_backend.dart';

class FakePrinter implements PrinterBackend {
  @override
  Future<void> printBytes({
    required PrinterConfig printer,
    required PrintJob job,
    required Uint8List bytes,
  }) async {
    final outputPath = printer.outputFile ?? './prints/output.txt';
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    final text = _printable(bytes);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    await file.writeAsString(
      '''
=== Print job at ${DateTime.now().toIso8601String()} ===
Printer: ${printer.name} (${printer.id})
Type: ${job.type}
Width: ${job.paperWidth}
Invoice: ${job.invoiceId}
--- ESC/POS bytes (printable view) ---
$text
--- Raw bytes (hex) ---
$hex

''',
      mode: FileMode.append,
      flush: true,
    );
  }

  String _printable(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      if (byte == 0x0a) {
        buffer.writeln();
      } else if (byte >= 32 && byte <= 126) {
        buffer.write(String.fromCharCode(byte));
      } else {
        buffer.write('<${byte.toRadixString(16).padLeft(2, '0')}>');
      }
    }
    return buffer.toString();
  }
}
