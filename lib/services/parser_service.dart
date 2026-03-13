import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../models/book.dart';

/// Result of parsing a book file into words
class ParsedBook {
  final String title;
  final String author;
  final List<String> words;
  final List<Chapter> chapters;

  const ParsedBook({
    required this.title,
    required this.author,
    required this.words,
    required this.chapters,
  });
}

class Chapter {
  final String title;
  final int startWordIndex;
  const Chapter({required this.title, required this.startWordIndex});
}

class BookParserService {
  static final BookParserService _i = BookParserService._();
  factory BookParserService() => _i;
  BookParserService._();

  /// Detect format from file extension
  BookFormat detectFormat(String path) {
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    return switch (ext) {
      'txt'  => BookFormat.txt,
      'fb2'  => BookFormat.fb2,
      'epub' => BookFormat.epub,
      'pdf'  => BookFormat.pdf,
      'docx' => BookFormat.docx,
      'html' || 'htm' => BookFormat.html,
      'rtf'  => BookFormat.rtf,
      'mobi' => BookFormat.mobi,
      _      => BookFormat.unknown,
    };
  }

  /// Parse any supported format into words list
  Future<ParsedBook> parse(String filePath, BookFormat format) async {
    return switch (format) {
      BookFormat.txt  => await _parseTxt(filePath),
      BookFormat.fb2  => await _parseFb2(filePath),
      BookFormat.html => await _parseHtml(filePath),
      BookFormat.epub => await _parseEpub(filePath),
      BookFormat.pdf  => await _parsePdf(filePath),
      BookFormat.docx => await _parseDocx(filePath),
      BookFormat.rtf  => await _parseRtf(filePath),
      BookFormat.mobi => await _parseMobi(filePath),
      _               => await _parseTxt(filePath),
    };
  }

  // ─── TXT ──────────────────────────────────────────────────
  Future<ParsedBook> _parseTxt(String path) async {
    final text = await File(path).readAsString();
    final name = p.basenameWithoutExtension(path);
    return _buildFromText(text, name, '');
  }

  // ─── FB2 (XML-based Russian format) ───────────────────────
  Future<ParsedBook> _parseFb2(String path) async {
    final raw = await File(path).readAsString();

    String title = _xmlTagContent(raw, 'book-title') ?? p.basenameWithoutExtension(path);
    String author = _buildAuthorFromFb2(raw);

    // Extract all <p> content between <body> tags
    final bodyMatch = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true).firstMatch(raw);
    final body = bodyMatch?.group(1) ?? raw;

    // Strip XML tags
    final text = body
        .replaceAll(RegExp(r'<section[^>]*>', dotAll: true), '\n\n')
        .replaceAll(RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true), '\n\n$1\n\n')
        .replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"');

    return _buildFromText(text, title, author);
  }

  String _buildAuthorFromFb2(String raw) {
    final first = _xmlTagContent(raw, 'first-name') ?? '';
    final last  = _xmlTagContent(raw, 'last-name')  ?? '';
    return '$first $last'.trim();
  }

  // ─── HTML ─────────────────────────────────────────────────
  Future<ParsedBook> _parseHtml(String path) async {
    final raw = await File(path).readAsString();
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true, caseSensitive: false).firstMatch(raw);
    final title = titleMatch?.group(1) ?? p.basenameWithoutExtension(path);
    // Strip scripts and styles first
    final clean = raw
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _buildFromText(clean, title, '');
  }

  // ─── EPUB (zip with HTML files) ───────────────────────────
  Future<ParsedBook> _parseEpub(String path) async {
    // epub_view package handles rendering; for word extraction we read raw HTML
    // This is a simplified extractor; full implementation uses epub_view
    final name = p.basenameWithoutExtension(path);
    // TODO: integrate epubx for full parsing
    return ParsedBook(
      title: name, author: '',
      words: ['[EPUB', 'parsing', 'requires', 'epubx', 'package', '—', 'integrated', 'via', 'epub_view]'],
      chapters: [Chapter(title: 'Chapter I', startWordIndex: 0)],
    );
  }

  // ─── PDF ──────────────────────────────────────────────────
  Future<ParsedBook> _parsePdf(String path) async {
    // Uses syncfusion_flutter_pdf — requires license for commercial use
    // or use pdf_text package for basic extraction
    final name = p.basenameWithoutExtension(path);
    return ParsedBook(
      title: name, author: '',
      words: ['[PDF', 'text', 'extraction', 'via', 'syncfusion_flutter_pdf]'],
      chapters: [Chapter(title: 'Page 1', startWordIndex: 0)],
    );
  }

  // ─── DOCX ─────────────────────────────────────────────────
  Future<ParsedBook> _parseDocx(String path) async {
    // DOCX is a ZIP; extract word/document.xml
    // Simplified: treat as ZIP and extract XML text
    final name = p.basenameWithoutExtension(path);
    return ParsedBook(
      title: name, author: '',
      words: ['[DOCX', 'parsing', 'via', 'archive', 'package', 'coming', 'soon]'],
      chapters: [Chapter(title: 'Document', startWordIndex: 0)],
    );
  }

  // ─── RTF ──────────────────────────────────────────────────
  Future<ParsedBook> _parseRtf(String path) async {
    final raw = await File(path).readAsString();
    // Strip RTF control words
    final text = raw
        .replaceAll(RegExp(r'\{[^{}]*\}'), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+\d*\s?'), ' ')
        .replaceAll(RegExp(r'[{}\\]'), '');
    return _buildFromText(text, p.basenameWithoutExtension(path), '');
  }

  // ─── MOBI ─────────────────────────────────────────────────
  Future<ParsedBook> _parseMobi(String path) async {
    // MOBI is complex; use a native bridge or convert to HTML first
    final name = p.basenameWithoutExtension(path);
    return ParsedBook(
      title: name, author: '',
      words: ['[MOBI', 'parsing', 'requires', 'native', 'bridge]'],
      chapters: [Chapter(title: 'Chapter I', startWordIndex: 0)],
    );
  }

  // ─── Shared helpers ───────────────────────────────────────
  ParsedBook _buildFromText(String text, String title, String author) {
    // Tokenize into words, filter empty
    final words = text
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    // Detect chapter headings (simple heuristic)
    final chapters = <Chapter>[];
    for (int i = 0; i < words.length; i++) {
      // Lines that are short and title-cased often are chapter titles
      if (i < words.length - 1 &&
          words[i].toLowerCase().startsWith('глав') ||
          words[i].toLowerCase() == 'chapter') {
        chapters.add(Chapter(
          title: words.sublist(i, (i + 3).clamp(0, words.length)).join(' '),
          startWordIndex: i,
        ));
      }
    }
    if (chapters.isEmpty) {
      chapters.add(Chapter(title: title, startWordIndex: 0));
    }

    return ParsedBook(title: title, author: author, words: words, chapters: chapters);
  }

  String? _xmlTagContent(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    return m?.group(1)?.trim().replaceAll(RegExp(r'<[^>]+>'), '');
  }

  /// ORP — Optimal Recognition Point index within a word
  static int orp(String word) {
    final n = word.length;
    if (n <= 1) return 0;
    if (n <= 5) return 1;
    if (n <= 9) return 2;
    if (n <= 13) return 3;
    return 4;
  }

  /// Compute delay multiplier for punctuation pauses
  static double punctuationMultiplier(String word) {
    if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) return 2.5;
    if (word.endsWith(',') || word.endsWith(';') || word.endsWith(':')) return 1.6;
    if (word.length > 10) return 1.3;
    return 1.0;
  }
}
