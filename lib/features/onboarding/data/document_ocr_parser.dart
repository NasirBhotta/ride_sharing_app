class LicenseOcrResult {
  const LicenseOcrResult({this.licenseNumber, this.licenseExpiry});

  final String? licenseNumber;
  final String? licenseExpiry;

  List<String> get filledFields {
    final fields = <String>[];
    if (licenseNumber != null) fields.add('license number');
    if (licenseExpiry != null) fields.add('expiry date');
    return fields;
  }
}

class IdCardOcrResult {
  const IdCardOcrResult({this.idNumber, this.fullName});

  final String? idNumber;
  final String? fullName;

  List<String> get filledFields {
    final fields = <String>[];
    if (idNumber != null) fields.add('ID number');
    if (fullName != null) fields.add('name');
    return fields;
  }
}

class DocumentOcrParser {
  static final _cnicPattern = RegExp(r'\b(\d{5}[-\s]?\d{7}[-\s]?\d)\b');
  static final _datePattern = RegExp(
    r'\b(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2})\b',
  );
  static final _licenseNumberPattern = RegExp(
    r'(?:LIC(?:ENSE)?|DL|D\.?L\.?)\s+(?:NO|NUMBER|#)[:\s]+([A-Z0-9][A-Z0-9\-]{4,18}[A-Z0-9])',
    caseSensitive: false,
  );
  static final _idLabelPattern = RegExp(
    r'(?:ID|CNIC|NATIONAL\s*ID|IDENTITY)\s+(?:NO|NUMBER|#)[:\s]+([A-Z0-9][A-Z0-9\-]{4,18})',
    caseSensitive: false,
  );
  static final _expiryLabelPattern = RegExp(
    r'(?:EXP(?:IRY)?|VALID\s*(?:UNTIL|THRU|TO)|EXPIRES?)[:\s]*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2})',
    caseSensitive: false,
  );
  static final _nameLabelPattern = RegExp(
    r'(?:NAME|HOLDER)[:\s]*([A-Z][A-Z\s]{2,40})',
    caseSensitive: false,
  );

  static LicenseOcrResult parseLicense(String rawText) {
    final lines = _normalizeLines(rawText);
    final joined = lines.join('\n');

    final expiry = _extractExpiry(joined, lines);
    final number = _extractLicenseNumber(joined, lines);

    return LicenseOcrResult(
      licenseNumber: number,
      licenseExpiry: expiry,
    );
  }

  static IdCardOcrResult parseIdCard(String rawText) {
    final lines = _normalizeLines(rawText);
    final joined = lines.join('\n');

    final idNumber = _extractIdNumber(joined, lines);
    final fullName = _extractName(joined, lines);

    return IdCardOcrResult(idNumber: idNumber, fullName: fullName);
  }

  static List<String> _normalizeLines(String rawText) {
    return rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String? _extractLicenseNumber(String joined, List<String> lines) {
    final labeled = _licenseNumberPattern.firstMatch(joined);
    if (labeled != null) {
      return _cleanToken(labeled.group(1));
    }

    for (final line in lines) {
      if (_looksLikeLabelOnly(line)) continue;
      if (_cnicPattern.hasMatch(line)) continue;
      if (_expiryLabelPattern.hasMatch(line)) continue;

      final upper = line.toUpperCase();
      if (upper.contains('LICENSE') ||
          upper.contains('DRIVER') ||
          upper.contains('LIC NO')) {
        final token = _firstAlphanumericToken(line);
        if (token != null && token.length >= 5) return token;
      }
    }

    for (final line in lines) {
      if (_looksLikeLabelOnly(line)) continue;
      if (_cnicPattern.hasMatch(line)) continue;
      final token = _firstAlphanumericToken(line);
      if (token != null && token.length >= 6 && token.length <= 20) {
        return token;
      }
    }

    return null;
  }

  static String? _extractIdNumber(String joined, List<String> lines) {
    final cnic = _cnicPattern.firstMatch(joined);
    if (cnic != null) {
      return _formatCnic(cnic.group(1)!);
    }

    final labeled = _idLabelPattern.firstMatch(joined);
    if (labeled != null) {
      final value = _cleanToken(labeled.group(1));
      if (value != null) return value;
    }

    for (final line in lines) {
      final digits = line.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 13) {
        return _formatCnic(digits);
      }
    }

    return null;
  }

  static String? _extractExpiry(String joined, List<String> lines) {
    final labeled = _expiryLabelPattern.firstMatch(joined);
    if (labeled != null) {
      return _normalizeDate(labeled.group(1));
    }

    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('EXP') ||
          upper.contains('VALID') ||
          upper.contains('EXPIR')) {
        final match = _datePattern.firstMatch(line);
        if (match != null) return _normalizeDate(match.group(1));
      }
    }

    return null;
  }

  static String? _extractName(String joined, List<String> lines) {
    final labeled = _nameLabelPattern.firstMatch(joined);
    if (labeled != null) {
      final name = labeled.group(1)?.trim();
      if (name != null && name.length > 2) return _titleCase(name);
    }

    for (var i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper == 'NAME' && i + 1 < lines.length) {
        final candidate = lines[i + 1].trim();
        if (_looksLikePersonName(candidate)) return _titleCase(candidate);
      }
    }

    return null;
  }

  static const _ignoredTokens = {
    'LICENSE',
    'LICENCE',
    'DRIVER',
    'DRIVING',
    'IDENTITY',
    'NATIONAL',
    'PAKISTAN',
    'NAME',
    'HOLDER',
    'CARD',
    'NUMBER',
  };

  static String? _firstAlphanumericToken(String line) {
    final match = RegExp(r'\b([A-Z0-9][A-Z0-9\-]{4,18}[A-Z0-9])\b', caseSensitive: false)
        .firstMatch(line);
    final token = match == null ? null : _cleanToken(match.group(1));
    if (token == null || _ignoredTokens.contains(token)) return null;
    return token;
  }

  static bool _looksLikeLabelOnly(String line) {
    final alpha = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return alpha.length >= 3 && !RegExp(r'\d').hasMatch(line);
  }

  static bool _looksLikePersonName(String value) {
    if (value.length < 3) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;
    return RegExp(r'^[A-Za-z][A-Za-z\s.\-]{2,}$').hasMatch(value);
  }

  static String? _cleanToken(String? value) {
    if (value == null) return null;
    final cleaned = value.trim().toUpperCase();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _formatCnic(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return raw.trim();
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }

  static String? _normalizeDate(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(RegExp(r'[-/.]')).map((p) => p.trim()).toList();
    if (parts.length != 3) return null;

    int year;
    int month;
    int day;

    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]) ?? 0;
      month = int.tryParse(parts[1]) ?? 0;
      day = int.tryParse(parts[2]) ?? 0;
    } else {
      final a = int.tryParse(parts[0]) ?? 0;
      final b = int.tryParse(parts[1]) ?? 0;
      year = int.tryParse(parts[2]) ?? 0;
      if (year < 100) year += 2000;

      if (a > 12) {
        day = a;
        month = b;
      } else if (b > 12) {
        month = a;
        day = b;
      } else {
        day = a;
        month = b;
      }
    }

    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (word) =>
              word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
