import 'package:firedart/firedart.dart';

import 'config.dart';
import 'template_renderer.dart';

class FirestoreClient {
  final HelperConfig config;
  late final Firestore _firestore;

  FirestoreClient(this.config);

  Future<void> initialize() async {
    FirebaseAuth.initialize(config.firebase.apiKey, VolatileStore());
    await FirebaseAuth.instance.signIn(
      config.firebase.email,
      config.firebase.password,
    );
    Firestore.initialize(config.firebase.projectId);
    _firestore = Firestore.instance;
  }

  Future<List<PrintJob>> pendingJobs() async {
    final docs =
        await _queue()
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt')
            .limit(10)
            .get();
    return docs.map(_jobFromDoc).toList();
  }

  Future<List<PrinterConfig>> networkPrinters() async {
    final docs = await _printers().get();
    return docs
        .where((doc) {
          final map = doc.map;
          return (map['isActive'] as bool? ?? true) &&
              (map['type'] as String? ?? 'network') == 'network';
        })
        .map((doc) {
          final map = doc.map;
          return PrinterConfig(
            id: doc.id,
            name: map['name'] as String? ?? 'Network printer',
            backend: 'network',
            host: map['ipAddress'] as String?,
            port: (map['port'] as num?)?.toInt() ?? 9100,
          );
        })
        .toList();
  }

  Future<void> markPrinting(PrintJob job) async {
    await _jobDoc(job.id).update({
      'status': 'printing',
      'attemptCount': job.attemptCount + 1,
      'lastError': null,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> markPrinted(PrintJob job) async {
    await _jobDoc(job.id).update({
      'status': 'printed',
      'printedAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'lastError': null,
    });
  }

  Future<void> markFailedOrRetry(PrintJob job, Object error) async {
    final attempts = job.attemptCount + 1;
    final permanent = attempts >= 3;
    await _jobDoc(job.id).update({
      'status': permanent ? 'failed' : 'pending',
      'lastError': error.toString(),
      'attemptCount': attempts,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> writeHeartbeat({required int printerCount}) async {
    await _helperDoc(config.helperId).set({
      'helperId': config.helperId,
      'restaurantId': config.restaurantId,
      'printerCount': printerCount,
      'lastSeenAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> writePrinterStatus({
    required PrinterConfig printer,
    required bool isReachable,
    required Object? error,
  }) async {
    final now = DateTime.now();
    await _printerStatusDoc(printer.id).set({
      'printerId': printer.id,
      'printerName': printer.name,
      'helperId': config.helperId,
      'backend': printer.backend,
      'host': printer.host,
      'port': printer.port,
      'isReachable': isReachable,
      'lastCheckedAt': now,
      'lastSuccessAt': isReachable ? now : null,
      'lastError': isReachable ? null : error?.toString(),
      'updatedAt': now,
    });
  }

  CollectionReference _queue() {
    return _firestore.collection(
      'restaurants/${config.restaurantId}/print_queue',
    );
  }

  CollectionReference _printers() {
    return _firestore.collection('restaurants/${config.restaurantId}/printers');
  }

  DocumentReference _jobDoc(String id) {
    return _firestore.document(
      'restaurants/${config.restaurantId}/print_queue/$id',
    );
  }

  DocumentReference _helperDoc(String id) {
    return _firestore.document(
      'restaurants/${config.restaurantId}/print_helper/$id',
    );
  }

  DocumentReference _printerStatusDoc(String id) {
    return _firestore.document(
      'restaurants/${config.restaurantId}/printer_status/$id',
    );
  }

  PrintJob _jobFromDoc(Document doc) {
    final map = doc.map;
    return PrintJob(
      id: doc.id,
      type: map['type'] as String? ?? 'bill',
      printerId: map['printerId'] as String? ?? '',
      invoiceId: map['invoiceId'] as String? ?? '',
      paperWidth: map['paperWidth'] as String? ?? 'mm80',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
    );
  }
}
