/// Same SMS → same id, whether it arrives live or is read from the inbox
/// later, so the two are recognised as one payment. Two 32-bit FNV-1a
/// hashes (web-safe integer maths) → 16 hex chars.
String smsContentId(String sender, String body) {
  final text = '${sender.trim().toUpperCase()}|${body.trim()}';
  int fnv(int seed) {
    var h = seed;
    for (final unit in text.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return 'c${hex(fnv(0x811C9DC5))}${hex(fnv(0x050C5D1F))}';
}
