import 'dart:convert';
import 'dart:typed_data';

enum PosAlign { left, center, right }

class EscPosGenerator {
  static const _init = [0x1b, 0x40];
  static const _alignLeft = [0x1b, 0x61, 0x00];
  static const _alignCenter = [0x1b, 0x61, 0x01];
  static const _alignRight = [0x1b, 0x61, 0x02];
  static const _boldOn = [0x1b, 0x45, 0x01];
  static const _boldOff = [0x1b, 0x45, 0x00];
  static const _sizeNormal = [0x1d, 0x21, 0x00];
  static const _sizeDouble = [0x1d, 0x21, 0x11];
  static const _cut = [0x1d, 0x56, 0x00];

  // ── Code page (ESC t n) ────────────────────────────────────────────────────
  // Common Arabic code page values — check your printer's manual:
  //   Epson TM series  → kCodePageCp864 (0x14)
  //   Star TSP/mPOP    → 0x1A
  //   Xprinter/Generic → try kCodePageCp864 first, then kCodePageCp1256
  static const kCodePageDefault = 0x00; // PC437 (standard Latin)
  static const kCodePageCp864 = 0x14; // IBM Arabic 864
  static const kCodePageCp1256 = 0x11; // Windows Arabic 1256 (some printers)
  static const kCodePagePc1001 = 0x21; // Arabic PC1001 on tested printer

  /// Select character code table: ESC t n
  static List<int> codePage(int page) => [0x1b, 0x74, page];

  // ── Standard methods ───────────────────────────────────────────────────────

  static List<int> initialize() => List.of(_init);

  static List<int> align(PosAlign align) {
    return switch (align) {
      PosAlign.left => List.of(_alignLeft),
      PosAlign.center => List.of(_alignCenter),
      PosAlign.right => List.of(_alignRight),
    };
  }

  static List<int> bold(bool enabled) =>
      enabled ? List.of(_boldOn) : List.of(_boldOff);

  static List<int> size({bool doubleSize = false}) {
    return doubleSize ? List.of(_sizeDouble) : List.of(_sizeNormal);
  }

  static List<int> text(String value) => latin1.encode(_sanitize(value));

  static List<int> line(String value) => [...text(value), 0x0a];

  static List<int> feed([int lines = 1]) => List.filled(lines, 0x0a);

  static List<int> separator(int width, {String char = '-'}) {
    return line(char * width);
  }

  static List<int> twoColumn(String left, String right, int width) {
    final l = truncate(left, width);
    final r = truncate(right, width);
    final spaces = width - l.length - r.length;
    return line('$l${spaces > 0 ? ' ' * spaces : ' '}$r');
  }

  static List<int> tableRow(List<String> cols, List<int> widths) {
    final b = StringBuffer();
    for (var i = 0; i < cols.length; i++) {
      b.write(pad(cols[i], widths[i]));
    }
    return line(b.toString());
  }

  static List<int> cut() => List.of(_cut);

  static Uint8List build(List<List<int>> parts) {
    final out = <int>[...initialize()];
    for (final part in parts) {
      out.addAll(part);
    }
    out.addAll(feed(3));
    out.addAll(cut());
    return Uint8List.fromList(out);
  }

  // ── Arabic support ─────────────────────────────────────────────────────────

  /// Encode an Arabic string as CP1256 (Windows-1256) bytes and append LF.
  /// The text is reversed so it renders RTL on a LTR printer head.
  ///
  /// Usage:
  ///   ...EscPosGenerator.codePage(kCodePageCp864),   // set Arabic code page
  ///   ...EscPosGenerator.arabicLine('اختبار العربية'),
  ///   ...EscPosGenerator.codePage(kCodePageDefault),  // restore Latin
  static List<int> arabicLine(String text) {
    // Reverse the string so the printer (which prints LTR) produces RTL output.
    final reversed = String.fromCharCodes(text.runes.toList().reversed);
    return [..._encodeCp1256(reversed), 0x0a];
  }

  /// Like [arabicLine] but without the trailing LF — for building mixed lines.
  static List<int> arabicText(String text) {
    final reversed = String.fromCharCodes(text.runes.toList().reversed);
    return _encodeCp1256(reversed);
  }

  /// Build a standalone Arabic test receipt to check printer compatibility.
  /// Call this instead of [build] when you only want the Arabic test page.
  static Uint8List buildArabicTest(int paperWidth) {
    final width = paperWidth == 58 ? 32 : 48;
    final sep = '-' * width;
    final parts = <List<int>>[
      // --- Receipt header ---
      align(PosAlign.center),
      bold(true),
      size(doubleSize: true),
      line('ICONIA CAFE'),
      size(),
      codePage(kCodePagePc1001),
      arabicLine('مطعم ايكونيا'),
      codePage(kCodePageDefault),
      bold(false),
      line('Test Invoice'),
      line(sep),

      align(PosAlign.left),
      twoColumn('Invoice', 'TEST-001', width),
      twoColumn('Date', '24/05/2026 21:30', width),
      twoColumn('Order', 'DINE-IN - Table 5', width),
      line(sep),

      tableRow(['Item', 'Qty', 'Total'], [width - 14, 4, 10]),
      line(sep),

      tableRow(['Karak Tea', '2', '6.00'], [width - 14, 4, 10]),
      codePage(kCodePagePc1001),
      align(PosAlign.right),
      arabicLine('شاي كرك'),
      codePage(kCodePageDefault),
      align(PosAlign.left),

      tableRow(['Chicken Wrap', '1', '18.00'], [width - 14, 4, 10]),
      codePage(kCodePagePc1001),
      align(PosAlign.right),
      arabicLine('راب دجاج'),
      codePage(kCodePageDefault),
      align(PosAlign.left),

      tableRow(['Water', '1', '2.00'], [width - 14, 4, 10]),
      codePage(kCodePagePc1001),
      align(PosAlign.right),
      arabicLine('ماء'),
      codePage(kCodePageDefault),
      align(PosAlign.left),

      line(sep),
      twoColumn('Subtotal', '26.00', width),
      twoColumn('VAT 5%', '1.30', width),
      bold(true),
      twoColumn('TOTAL', 'AED 27.30', width),
      bold(false),
      line(sep),

      align(PosAlign.center),
      line('Thank you for your visit'),
      codePage(kCodePagePc1001),
      arabicLine('شكرا لزيارتكم'),
      codePage(kCodePageDefault),
      align(PosAlign.center),
      line('Arabic code page: ESC t 21'),
    ];

    final out = <int>[...initialize()];
    for (final part in parts) {
      out.addAll(part);
    }
    out.addAll(feed(4));
    out.addAll(cut());
    return Uint8List.fromList(out);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String truncate(String text, int width) {
    if (text.length <= width) return text;
    if (width <= 3) return text.substring(0, width);
    return '${text.substring(0, width - 3)}...';
  }

  static String pad(String text, int width, {bool leftAlign = true}) {
    final value = truncate(text, width);
    final padding = ' ' * (width - value.length);
    return leftAlign ? '$value$padding' : '$padding$value';
  }

  static String _sanitize(String input) {
    return input
        .replaceAll('د.إ', 'AED')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('·', '-')
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');
  }

  /// Encode a string using Windows-1256 (CP1256).
  /// ASCII bytes pass through unchanged; Arabic Unicode maps to CP1256 bytes.
  static List<int> _encodeCp1256(String text) {
    return text.runes.map((cp) {
      if (cp < 0x80) return cp; // ASCII passthrough
      return _cp1256[cp] ?? 0x3F; // '?' for unmapped characters
    }).toList();
  }

  // Unicode → Windows-1256 (CP1256) for Arabic characters.
  static const _cp1256 = <int, int>{
    // Arabic punctuation
    0x060C: 0xAC, // ،
    0x061B: 0xBB, // ؛
    0x061F: 0xBF, // ؟
    // Arabic alphabet U+0621–U+063A
    0x0621: 0xC1, // ء
    0x0622: 0xC2, // آ
    0x0623: 0xC3, // أ
    0x0624: 0xC4, // ؤ
    0x0625: 0xC5, // إ
    0x0626: 0xC6, // ئ
    0x0627: 0xC7, // ا
    0x0628: 0xC8, // ب
    0x0629: 0xC9, // ة
    0x062A: 0xCA, // ت
    0x062B: 0xCB, // ث
    0x062C: 0xCC, // ج
    0x062D: 0xCD, // ح
    0x062E: 0xCE, // خ
    0x062F: 0xCF, // د
    0x0630: 0xD0, // ذ
    0x0631: 0xD1, // ر
    0x0632: 0xD2, // ز
    0x0633: 0xD3, // س
    0x0634: 0xD4, // ش
    0x0635: 0xD5, // ص
    0x0636: 0xD6, // ض
    0x0637: 0xD8, // ط
    0x0638: 0xD9, // ظ
    0x0639: 0xDA, // ع
    0x063A: 0xDB, // غ
    0x0640: 0xDC, // ـ tatweel
    0x0641: 0xDD, // ف
    0x0642: 0xDE, // ق
    0x0643: 0xDF, // ك
    0x0644: 0xE1, // ل
    0x0645: 0xE3, // م
    0x0646: 0xE4, // ن
    0x0647: 0xE5, // ه
    0x0648: 0xE6, // و
    0x0649: 0xE7, // ى alef maqsura
    0x064A: 0xE8, // ي
    // Diacritics (tashkeel)
    0x064B: 0xEA, // ً fathatan
    0x064C: 0xEB, // ٌ dammatan
    0x064D: 0xEC, // ٍ kasratan
    0x064E: 0xED, // َ fatha
    0x064F: 0xEE, // ُ damma
    0x0650: 0xEF, // ِ kasra
    0x0651: 0xF0, // ّ shadda
    0x0652: 0xF1, // ْ sukun
    // Extended Arabic (Farsi/Urdu — present in CP1256)
    0x067E: 0x81, // پ pe
    0x0686: 0x8D, // چ cheh
    0x0698: 0x8E, // ژ jeh
    0x0688: 0x8F, // ڈ
    0x06A9: 0x90, // ک farsi kaf
    0x06AF: 0x83, // گ gaf
    0x06BA: 0x9A, // ں
    0x06BE: 0xAA, // ھ do chashmi he
    0x06C1: 0xBA, // ہ he goal
  };
}
