/// Formats a whole-number count for compact HUD display:
/// thousands get a separator; ten-thousands and up are abbreviated with K/M.
String formatCount(int n) {
  final neg = n < 0;
  final a = n.abs();
  String body;
  if (a >= 1000000) {
    final m = a / 1000000;
    body = '${_trim(m)}M';
  } else if (a >= 10000) {
    final k = a / 1000;
    body = '${_trim(k)}K';
  } else {
    body = _grouped(a);
  }
  return neg ? '-$body' : body;
}

/// One decimal, but drop a trailing ".0" (1.0K -> 1K, 1.2K stays).
String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Inserts comma thousands separators (1234 -> "1,234").
String _grouped(int a) {
  final s = a.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
