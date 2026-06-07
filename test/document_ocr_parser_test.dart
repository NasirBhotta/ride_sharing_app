import 'package:flutter_test/flutter_test.dart';
import 'package:ride_sharing_app/features/onboarding/data/document_ocr_parser.dart';

void main() {
  group('DocumentOcrParser', () {
    test('parseLicense extracts number and expiry', () {
      const raw = '''
DRIVER LICENSE
LICENSE NO: ABC123456
EXP: 12/31/2028
NAME JOHN DOE
''';

      final result = DocumentOcrParser.parseLicense(raw);

      expect(result.licenseNumber, 'ABC123456');
      expect(result.licenseExpiry, '2028-12-31');
    });

    test('parseIdCard extracts CNIC', () {
      const raw = '''
NATIONAL ID CARD
CNIC: 35202-1234567-1
NAME ALI AHMED
''';

      final result = DocumentOcrParser.parseIdCard(raw);

      expect(result.idNumber, '35202-1234567-1');
    });
  });
}
