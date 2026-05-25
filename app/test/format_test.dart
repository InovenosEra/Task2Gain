import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/util/format.dart';

void main() {
  test('small numbers are plain', () {
    expect(formatCount(0), '0');
    expect(formatCount(58), '58');
    expect(formatCount(999), '999');
  });

  test('thousands get a separator', () {
    expect(formatCount(1000), '1,000');
    expect(formatCount(1234), '1,234');
    expect(formatCount(9999), '9,999');
  });

  test('ten-thousands and up abbreviate with K', () {
    expect(formatCount(10000), '10K');
    expect(formatCount(12300), '12.3K');
    expect(formatCount(999999), '1000K');
  });

  test('millions abbreviate with M', () {
    expect(formatCount(1000000), '1M');
    expect(formatCount(2500000), '2.5M');
  });

  test('negatives keep their sign', () {
    expect(formatCount(-1234), '-1,234');
  });
}
