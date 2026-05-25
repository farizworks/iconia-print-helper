import 'dart:convert';
import 'dart:io';

class HelperConfig {
  final FirebaseConfig firebase;
  final String helperId;
  final String restaurantId;
  final List<PrinterConfig> printers;
  final String? logoPath;
  final int logoWidthPercent;

  const HelperConfig({
    required this.firebase,
    required this.helperId,
    required this.restaurantId,
    required this.printers,
    this.logoPath,
    this.logoWidthPercent = 50,
  });

  PrinterConfig? printerById(String id) {
    for (final printer in printers) {
      if (printer.id == id) return printer;
    }
    return null;
  }

  static Future<HelperConfig> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Config file not found: $path');
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final firebase = data['firebase'] as Map<String, dynamic>? ?? {};
    final printers = data['printers'] as List<dynamic>? ?? [];
    final rawHelperId =
        data['helperId'] as String? ?? 'helper-${Platform.localHostname}';
    return HelperConfig(
      firebase: FirebaseConfig(
        projectId: firebase['projectId'] as String? ?? '',
        apiKey: firebase['apiKey'] as String? ?? '',
        email: firebase['email'] as String? ?? '',
        password: firebase['password'] as String? ?? '',
      ),
      helperId: rawHelperId.replaceAll('/', '-').trim(),
      restaurantId: data['restaurantId'] as String? ?? '',
      logoPath: data['logoPath'] as String?,
      logoWidthPercent: (data['logoWidthPercent'] as num?)?.toInt() ?? 50,
      printers:
          printers
              .map((p) => PrinterConfig.fromMap(p as Map<String, dynamic>))
              .toList(),
    );
  }
}

class FirebaseConfig {
  final String projectId;
  final String apiKey;
  final String email;
  final String password;

  const FirebaseConfig({
    required this.projectId,
    required this.apiKey,
    required this.email,
    required this.password,
  });
}

class PrinterConfig {
  final String id;
  final String name;
  final String backend;
  final String? outputFile;
  final String? host;
  final int port;

  const PrinterConfig({
    required this.id,
    required this.name,
    required this.backend,
    this.outputFile,
    this.host,
    this.port = 9100,
  });

  factory PrinterConfig.fromMap(Map<String, dynamic> map) {
    return PrinterConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      backend: map['backend'] as String? ?? 'fake',
      outputFile: map['outputFile'] as String?,
      host: map['host'] as String?,
      port: (map['port'] as num?)?.toInt() ?? 9100,
    );
  }
}
