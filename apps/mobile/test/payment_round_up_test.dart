import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/utils/formatters.dart';

void main() {
  group('roundUpRupee (payment collection amounts)', () {
    test('rounds any paise UP to the next rupee', () {
      expect(roundUpRupee(57.47), 58);
      expect(roundUpRupee(57.01), 58);
      expect(roundUpRupee(57.99), 58);
      expect(roundUpRupee(0.5), 1);
    });

    test('leaves whole-rupee amounts unchanged', () {
      expect(roundUpRupee(57), 57);
      expect(roundUpRupee(0), 0);
      expect(roundUpRupee(16400), 16400);
    });

    test('ignores floating-point noise on exact amounts', () {
      expect(roundUpRupee(57.000000001), 57);
      expect(roundUpRupee(0.1 + 0.2 + 56.7), 57);
    });
  });
}
