import 'dart:typed_data';

import 'esc_pos_generator.dart';

class TemplateRenderer {
  final Uint8List? logoBytes;
  final int logoWidthPercent;

  TemplateRenderer({this.logoBytes, this.logoWidthPercent = 50});

  Uint8List render(PrintJob job) {
    return switch (job.type) {
      'test' => _renderTest(job),
      'kot' => _renderKot(job),
      _ => _renderBill(job),
    };
  }

  String debugPreview(PrintJob job) {
    return switch (job.type) {
      'test' => _debugTest(job),
      'kot' => _debugKot(job),
      _ => _debugBill(job),
    };
  }

  Uint8List _renderTest(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    final paperWidthPx = job.paperWidth == 'mm58' ? 384 : 576;
    final parts = <List<int>>[
      EscPosGenerator.align(PosAlign.center),
      if (logoBytes != null) ...[
        EscPosGenerator.rasterImage(logoBytes!, paperWidthPx, logoWidthPercent: logoWidthPercent),
        EscPosGenerator.feed(1),
      ],
      EscPosGenerator.bold(true),
      EscPosGenerator.size(doubleSize: true),
      EscPosGenerator.line('TEST PRINT'),
      EscPosGenerator.size(),
      ..._textLine('اختبار الطباعة', arabicAlign: PosAlign.center, restoreAlign: PosAlign.center),
      EscPosGenerator.bold(false),
      EscPosGenerator.separator(width, char: '='),
      EscPosGenerator.align(PosAlign.left),
      EscPosGenerator.twoColumn('Printer', p.string('printerName'), width),
      EscPosGenerator.twoColumn('IP', p.string('ipAddress'), width),
      EscPosGenerator.twoColumn('Time', p.string('testedAt'), width),
      EscPosGenerator.separator(width, char: '='),
      EscPosGenerator.tableRow(['Item', 'Qty', 'Total'], [width - 14, 4, 10]),
      EscPosGenerator.separator(width),
      EscPosGenerator.tableRow(['Karak Tea', '2', '6.00'], [width - 14, 4, 10]),
      ..._textLine('شاي كرك', arabicAlign: PosAlign.left),
      EscPosGenerator.tableRow(['Chicken Wrap', '1', '18.00'], [width - 14, 4, 10]),
      ..._textLine('راب دجاج', arabicAlign: PosAlign.left),
      EscPosGenerator.tableRow(['Water', '1', '2.00'], [width - 14, 4, 10]),
      ..._textLine('ماء', arabicAlign: PosAlign.left),
      EscPosGenerator.separator(width),
      EscPosGenerator.twoColumn('Subtotal', 'AED 26.00', width),
      EscPosGenerator.twoColumn('VAT 5%', 'AED 1.30', width),
      EscPosGenerator.bold(true),
      EscPosGenerator.twoColumn('TOTAL', 'AED 27.30', width),
      ..._textLine('الإجمالي', arabicAlign: PosAlign.left),
      EscPosGenerator.bold(false),
      EscPosGenerator.separator(width),
      EscPosGenerator.twoColumn('Payment', 'Cash', width),
      ..._textLine('طريقة الدفع: نقداً', arabicAlign: PosAlign.left),
      EscPosGenerator.separator(width),
      EscPosGenerator.align(PosAlign.center),
      EscPosGenerator.line('Thank you for your visit!'),
      ..._textLine('شكرا لزيارتكم', arabicAlign: PosAlign.center, restoreAlign: PosAlign.center),
    ];
    return EscPosGenerator.build(parts);
  }

  String _debugTest(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    return [
      _center('TEST PRINT', width),
      _center('اختبار الطباعة', width),
      '=' * width,
      _twoColumn('Printer', p.string('printerName'), width),
      _twoColumn('IP', p.string('ipAddress'), width),
      _twoColumn('Time', p.string('testedAt'), width),
      '=' * width,
      _tableRow(['Item', 'Qty', 'Total'], [width - 14, 4, 10]),
      '-' * width,
      _tableRow(['Karak Tea', '2', '6.00'], [width - 14, 4, 10]),
      'شاي كرك',
      _tableRow(['Chicken Wrap', '1', '18.00'], [width - 14, 4, 10]),
      'راب دجاج',
      _tableRow(['Water', '1', '2.00'], [width - 14, 4, 10]),
      'ماء',
      '-' * width,
      _twoColumn('Subtotal', 'AED 26.00', width),
      _twoColumn('VAT 5%', 'AED 1.30', width),
      _twoColumn('TOTAL', 'AED 27.30', width),
      'الإجمالي',
      '-' * width,
      _twoColumn('Payment', 'Cash', width),
      'طريقة الدفع: نقداً',
      '-' * width,
      _center('Thank you for your visit!', width),
      _center('شكرا لزيارتكم', width),
    ].join('\n');
  }

  Uint8List _renderBill(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    final paperWidthPx = job.paperWidth == 'mm58' ? 384 : 576;
    final sym = p.string('currencySymbol', fallback: 'AED');
    final parts = <List<int>>[
      EscPosGenerator.align(PosAlign.center),
      if (logoBytes != null) ...[
        EscPosGenerator.rasterImage(logoBytes!, paperWidthPx, logoWidthPercent: logoWidthPercent),
        EscPosGenerator.feed(1),
      ],
      EscPosGenerator.bold(true),
      EscPosGenerator.size(doubleSize: true),
      ..._textLine(
        p.string('businessName', fallback: 'Restaurant'),
        arabicAlign: PosAlign.center,
        restoreAlign: PosAlign.center,
      ),
      EscPosGenerator.size(),
      EscPosGenerator.bold(false),
      if (p.hasText('businessAddress'))
        ..._textLine(
          p.string('businessAddress'),
          arabicAlign: PosAlign.center,
          restoreAlign: PosAlign.center,
        ),
      if (p.hasText('businessPhone'))
        EscPosGenerator.line('Tel: ${p.string('businessPhone')}'),
      if (p.hasText('trn')) EscPosGenerator.line('TRN: ${p.string('trn')}'),
      EscPosGenerator.bold(true),
      EscPosGenerator.line(
        p.boolValue('taxEnabled') ? 'TAX INVOICE' : 'INVOICE',
      ),
      EscPosGenerator.bold(false),
      EscPosGenerator.align(PosAlign.left),
      EscPosGenerator.separator(width, char: '='),
      EscPosGenerator.twoColumn('Invoice', p.string('invoiceNumber'), width),
      EscPosGenerator.twoColumn('Date', p.string('createdAt'), width),
      ..._labelValueLine('Order', p.string('orderType'), width),
      if (p.hasText('externalOrderNumber'))
        EscPosGenerator.twoColumn(
          'App Ref',
          p.string('externalOrderNumber'),
          width,
        ),
      if (p.hasText('customerName'))
        ..._labelValueLine('Customer', p.string('customerName'), width),
      if (p.hasText('customerPhone'))
        EscPosGenerator.twoColumn('Phone', p.string('customerPhone'), width),
      if (p.hasText('customerAddress'))
        ..._labelValueLine('Address', p.string('customerAddress'), width),
      if (p.hasText('specialInstructions'))
        ..._labelValueLine('Notes', p.string('specialInstructions'), width),
      EscPosGenerator.separator(width),
      EscPosGenerator.tableRow(['Item', 'Qty', 'Total'], [width - 14, 4, 10]),
      EscPosGenerator.separator(width),
    ];

    for (final item in p.items) {
      final name =
          item.string('variant').isEmpty
              ? item.string('name')
              : '${item.string('name')} (${item.string('variant')})';
      final nameArabic =
          item.string('variantArabic').isEmpty
              ? item.string('nameArabic')
              : '${item.string('nameArabic')} (${item.string('variantArabic')})';
      if (_hasArabic(name)) {
        parts.addAll(_textLine(name, arabicAlign: PosAlign.left));
        parts.add(
          EscPosGenerator.twoColumn(
            '  Qty ${item.numValue('qty').toStringAsFixed(0)}',
            _money(sym, item.numValue('lineTotal')),
            width,
          ),
        );
      } else {
        parts.add(
          EscPosGenerator.tableRow(
            [
              name,
              item.numValue('qty').toStringAsFixed(0),
              _money(sym, item.numValue('lineTotal')),
            ],
            [width - 14, 4, 10],
          ),
        );
      }
      if (nameArabic.trim().isNotEmpty) {
        parts.addAll(_textLine(nameArabic, arabicAlign: PosAlign.left));
      }
      if (item.hasText('note')) {
        parts.addAll(_noteLine(item.string('note')));
      }
    }

    parts.addAll([
      EscPosGenerator.separator(width),
      EscPosGenerator.twoColumn(
        'Subtotal',
        _money(sym, p.numValue('subtotal')),
        width,
      ),
      if (p.numValue('serviceCharge') > 0)
        EscPosGenerator.twoColumn(
          _serviceChargeLabel(
            p.string('serviceChargeLabel', fallback: 'Service Charge'),
            p.numValue('serviceChargePercentage'),
          ),
          _money(sym, p.numValue('serviceCharge')),
          width,
        ),
      if (p.numValue('deliveryCharge') > 0)
        EscPosGenerator.twoColumn(
          'Delivery',
          _money(sym, p.numValue('deliveryCharge')),
          width,
        ),
      if (p.numValue('taxAmount') > 0)
        ..._amountLine(
          '${p.boolValue('taxInclusive') ? 'Incl. ' : ''}${_percentageLabel(p.string('taxLabel', fallback: 'Tax'), p.numValue('taxPercentage'))}',
          _money(sym, p.numValue('taxAmount')),
          width,
        ),
      if (p.numValue('discount') > 0)
        EscPosGenerator.twoColumn(
          'Discount',
          '- ${_money(sym, p.numValue('discount'))}',
          width,
        ),
      EscPosGenerator.separator(width),
      EscPosGenerator.bold(true),
      EscPosGenerator.twoColumn(
        'TOTAL',
        _money(sym, p.numValue('total')),
        width,
      ),
      ..._textLine('الإجمالي', arabicAlign: PosAlign.left),
      EscPosGenerator.bold(false),
      if (p.numValue('totalRefunded') > 0)
        EscPosGenerator.twoColumn(
          'Refunded',
          '- ${_money(sym, p.numValue('totalRefunded'))}',
          width,
        ),
      if (p.hasText('status') && p.string('status') != 'confirmed')
        EscPosGenerator.line('STATUS: ${p.string('status').toUpperCase()}'),
    ]);

    if (p.payments.isNotEmpty) {
      for (final payment in p.payments) {
        parts.add(
          EscPosGenerator.twoColumn(
            'Paid - ${payment.string('method')}',
            _money(sym, payment.numValue('amount')),
            width,
          ),
        );
        parts.addAll(
          _textLine(
            'مدفوع - ${_paymentArabicLabel(payment.string('method'))}',
            arabicAlign: PosAlign.left,
          ),
        );
      }
    } else {
      parts.add(
        EscPosGenerator.twoColumn('Payment', p.string('paymentMethod'), width),
      );
      parts.addAll(
        _textLine(
          'طريقة الدفع: ${_paymentArabicLabel(p.string('paymentMethod'))}',
          arabicAlign: PosAlign.left,
        ),
      );
    }

    parts.addAll([
      EscPosGenerator.separator(width),
      EscPosGenerator.align(PosAlign.center),
      EscPosGenerator.line('Thank you for your visit!'),
      ..._textLine('شكرا لزيارتكم', arabicAlign: PosAlign.center, restoreAlign: PosAlign.center),
      EscPosGenerator.line('Powered by Invozora'),
    ]);

    return EscPosGenerator.build(parts);
  }

  String _debugBill(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    final sym = p.string('currencySymbol', fallback: 'AED');
    final lines = <String>[
      _center(p.string('businessName', fallback: 'Restaurant'), width),
      if (p.hasText('businessAddress'))
        _center(p.string('businessAddress'), width),
      if (p.hasText('businessPhone'))
        _center('Tel: ${p.string('businessPhone')}', width),
      if (p.hasText('trn')) _center('TRN: ${p.string('trn')}', width),
      _center(p.boolValue('taxEnabled') ? 'TAX INVOICE' : 'INVOICE', width),
      '=' * width,
      _twoColumn('Invoice', p.string('invoiceNumber'), width),
      _twoColumn('Date', p.string('createdAt'), width),
      _labelValue('Order', p.string('orderType'), width),
      if (p.hasText('externalOrderNumber'))
        _twoColumn('App Ref', p.string('externalOrderNumber'), width),
      if (p.hasText('customerName'))
        _labelValue('Customer', p.string('customerName'), width),
      if (p.hasText('customerPhone'))
        _twoColumn('Phone', p.string('customerPhone'), width),
      if (p.hasText('customerAddress'))
        _labelValue('Address', p.string('customerAddress'), width),
      if (p.hasText('specialInstructions'))
        _labelValue('Notes', p.string('specialInstructions'), width),
      '-' * width,
      _tableRow(['Item', 'Qty', 'Total'], [width - 14, 4, 10]),
      '-' * width,
    ];

    for (final item in p.items) {
      final name = item.string('variant').isEmpty
          ? item.string('name')
          : '${item.string('name')} (${item.string('variant')})';
      final nameArabic = item.string('variantArabic').isEmpty
          ? item.string('nameArabic')
          : '${item.string('nameArabic')} (${item.string('variantArabic')})';
      if (_hasArabic(name)) {
        lines.add(name);
        lines.add(
          _twoColumn(
            '  Qty ${item.numValue('qty').toStringAsFixed(0)}',
            _money(sym, item.numValue('lineTotal')),
            width,
          ),
        );
      } else {
        lines.add(
          _tableRow(
            [
              name,
              item.numValue('qty').toStringAsFixed(0),
              _money(sym, item.numValue('lineTotal')),
            ],
            [width - 14, 4, 10],
          ),
        );
      }
      if (nameArabic.trim().isNotEmpty) lines.add(nameArabic);
      if (item.hasText('note')) lines.add('  Note: ${item.string('note')}');
    }

    lines.addAll([
      '-' * width,
      _twoColumn('Subtotal', _money(sym, p.numValue('subtotal')), width),
      if (p.numValue('serviceCharge') > 0)
        _twoColumn(
          _serviceChargeLabel(
            p.string('serviceChargeLabel', fallback: 'Service Charge'),
            p.numValue('serviceChargePercentage'),
          ),
          _money(sym, p.numValue('serviceCharge')),
          width,
        ),
      if (p.numValue('deliveryCharge') > 0)
        _twoColumn('Delivery', _money(sym, p.numValue('deliveryCharge')), width),
      if (p.numValue('taxAmount') > 0)
        _twoColumn(
          '${p.boolValue('taxInclusive') ? 'Incl. ' : ''}${_percentageLabel(p.string('taxLabel', fallback: 'Tax'), p.numValue('taxPercentage'))}',
          _money(sym, p.numValue('taxAmount')),
          width,
        ),
      if (p.numValue('discount') > 0)
        _twoColumn(
          'Discount',
          '- ${_money(sym, p.numValue('discount'))}',
          width,
        ),
      '-' * width,
      _twoColumn('TOTAL', _money(sym, p.numValue('total')), width),
      'الإجمالي',
      if (p.numValue('totalRefunded') > 0)
        _twoColumn(
          'Refunded',
          '- ${_money(sym, p.numValue('totalRefunded'))}',
          width,
        ),
      if (p.hasText('status') && p.string('status') != 'confirmed')
        'STATUS: ${p.string('status').toUpperCase()}',
    ]);

    if (p.payments.isNotEmpty) {
      for (final payment in p.payments) {
        lines.add(
          _twoColumn(
            'Paid - ${payment.string('method')}',
            _money(sym, payment.numValue('amount')),
            width,
          ),
        );
        lines.add('مدفوع - ${_paymentArabicLabel(payment.string('method'))}');
      }
    } else {
      lines.add(_twoColumn('Payment', p.string('paymentMethod'), width));
      lines.add(
        'طريقة الدفع: ${_paymentArabicLabel(p.string('paymentMethod'))}',
      );
    }
    lines.addAll([
      '-' * width,
      _center('Thank you for your visit!', width),
      _center('Powered by Invozora', width),
    ]);
    return lines.join('\n');
  }

  Uint8List _renderKot(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    final parts = <List<int>>[
      EscPosGenerator.align(PosAlign.center),
      EscPosGenerator.bold(true),
      EscPosGenerator.size(doubleSize: true),
      EscPosGenerator.line('KOT'),
      EscPosGenerator.size(),
      EscPosGenerator.bold(false),
      EscPosGenerator.align(PosAlign.left),
      EscPosGenerator.separator(width, char: '='),
      EscPosGenerator.twoColumn('Invoice', p.string('invoiceNumber'), width),
      EscPosGenerator.twoColumn('Time', p.string('createdAt'), width),
      ..._labelValueLine('Order', p.string('orderType'), width),
      EscPosGenerator.separator(width),
    ];

    for (final item in p.items) {
      final variant = item.string('variant');
      final quantity = item.numValue('qty').toStringAsFixed(0);
      parts.add(EscPosGenerator.bold(true));
      if (_hasArabic(item.string('name'))) {
        parts.add(EscPosGenerator.line('${quantity}x'));
        parts.addAll(
          _textLine(item.string('name'), arabicAlign: PosAlign.left),
        );
      } else {
        parts.add(EscPosGenerator.line('${quantity}x ${item.string('name')}'));
      }
      parts.add(EscPosGenerator.bold(false));
      if (variant.isNotEmpty) {
        parts.addAll(_textLine(variant, arabicAlign: PosAlign.left));
      }
      final nameArabic =
          item.string('variantArabic').isEmpty
              ? item.string('nameArabic')
              : '${item.string('nameArabic')} (${item.string('variantArabic')})';
      if (nameArabic.trim().isNotEmpty) {
        parts.addAll(_textLine(nameArabic, arabicAlign: PosAlign.left));
      }
      if (item.hasText('note')) {
        parts.addAll(_noteLine(item.string('note')));
      }
    }

    parts.add(EscPosGenerator.separator(width));
    return EscPosGenerator.build(parts);
  }

  String _debugKot(PrintJob job) {
    final p = job.payload;
    final width = _width(job.paperWidth);
    final lines = <String>[
      _center('KOT', width),
      '=' * width,
      _twoColumn('Invoice', p.string('invoiceNumber'), width),
      _twoColumn('Time', p.string('createdAt'), width),
      _labelValue('Order', p.string('orderType'), width),
      '-' * width,
    ];
    for (final item in p.items) {
      final variant = item.string('variant');
      final nameArabic = item.string('variantArabic').isEmpty
          ? item.string('nameArabic')
          : '${item.string('nameArabic')} (${item.string('variantArabic')})';
      lines.add(
        '${item.numValue('qty').toStringAsFixed(0)}x ${item.string('name')}',
      );
      if (variant.isNotEmpty) lines.add(variant);
      if (nameArabic.trim().isNotEmpty) lines.add(nameArabic);
      if (item.hasText('note')) lines.add('  Note: ${item.string('note')}');
    }
    lines.add('-' * width);
    return lines.join('\n');
  }

  int _width(String paperWidth) => paperWidth == 'mm58' ? 32 : 48;
  String _money(String sym, double value) => '$sym ${value.toStringAsFixed(2)}';
  String _serviceChargeLabel(String label, double percentage) =>
      percentage > 0 ? '$label (${percentage.toStringAsFixed(0)}%)' : label;
  String _percentageLabel(String label, double percentage) =>
      percentage > 0 ? '$label ${percentage.toStringAsFixed(0)}%' : label;

  String _center(String text, int width) {
    if (text.length >= width) return text;
    return '${' ' * ((width - text.length) ~/ 2)}$text';
  }

  String _twoColumn(String left, String right, int width) {
    final l = _truncate(left, width);
    final r = _truncate(right, width);
    final spaces = width - l.length - r.length;
    return '$l${spaces > 0 ? ' ' * spaces : ' '}$r';
  }

  String _tableRow(List<String> columns, List<int> widths) {
    final row = StringBuffer();
    for (var index = 0; index < columns.length; index++) {
      final value = _truncate(columns[index], widths[index]);
      row.write('$value${' ' * (widths[index] - value.length)}');
    }
    return row.toString();
  }

  String _truncate(String text, int width) {
    if (text.length <= width) return text;
    if (width <= 3) return text.substring(0, width);
    return '${text.substring(0, width - 3)}...';
  }

  String _labelValue(String label, String value, int width) {
    if (_hasArabic(value)) return '$label:\n$value';
    return _twoColumn(label, value, width);
  }

  String _paymentArabicLabel(String method) => switch (method.toLowerCase()) {
    'cash' => 'نقداً',
    'card' => 'بطاقة',
    'bank transfer' => 'تحويل بنكي',
    'partial' => 'دفع متعدد',
    _ => method,
  };

  bool _hasArabic(String text) => RegExp(r'[\u0600-\u06ff]').hasMatch(text);

  List<List<int>> _textLine(
    String text, {
    PosAlign arabicAlign = PosAlign.right,
    PosAlign restoreAlign = PosAlign.left,
  }) {
    if (!_hasArabic(text)) return [EscPosGenerator.line(text)];
    return [
      EscPosGenerator.codePage(EscPosGenerator.kCodePagePc1001),
      EscPosGenerator.align(arabicAlign),
      EscPosGenerator.arabicLine(text),
      EscPosGenerator.codePage(EscPosGenerator.kCodePageDefault),
      EscPosGenerator.align(restoreAlign),
    ];
  }

  List<List<int>> _labelValueLine(String label, String value, int width) {
    if (!_hasArabic(value)) {
      return [EscPosGenerator.twoColumn(label, value, width)];
    }
    return [EscPosGenerator.line('$label:'), ..._textLine(value)];
  }

  List<List<int>> _amountLine(String label, String value, int width) {
    if (!_hasArabic(label)) {
      return [EscPosGenerator.twoColumn(label, value, width)];
    }
    return [..._textLine(label), EscPosGenerator.twoColumn('', value, width)];
  }

  List<List<int>> _noteLine(String note) {
    if (!_hasArabic(note)) {
      return [EscPosGenerator.line('  Note: $note')];
    }
    return [
      EscPosGenerator.line('  Note:'),
      ..._textLine(note, arabicAlign: PosAlign.left),
    ];
  }
}

class PrintJob {
  final String id;
  final String type;
  final String printerId;
  final String invoiceId;
  final String paperWidth;
  final Map<String, dynamic> payload;
  final int attemptCount;

  const PrintJob({
    required this.id,
    required this.type,
    required this.printerId,
    required this.invoiceId,
    required this.paperWidth,
    required this.payload,
    required this.attemptCount,
  });
}

extension _PayloadMap on Map<String, dynamic> {
  String string(String key, {String fallback = ''}) {
    final value = this[key];
    if (value == null) return fallback;
    return value.toString();
  }

  bool hasText(String key) => string(key).trim().isNotEmpty;

  double numValue(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool boolValue(String key) => this[key] == true;

  List<Map<String, dynamic>> get items {
    return (this['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get payments {
    return (this['payments'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((payment) => Map<String, dynamic>.from(payment))
        .toList();
  }
}
