/// The numeric Splitwise group id from a pasted group link, e.g.
/// `https://secure.splitwise.com/#/groups/12345678`, `.../groups/12345678/...`
/// or just `12345678`. Null if there isn't one.
int? parseGroupId(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'groups/(\d{1,15})(?!\d)').firstMatch(text) ?? RegExp(r'^(\d{1,15})$').firstMatch(text);
  final id = match == null ? null : int.tryParse(match.group(1)!);
  return id == null || id <= 0 ? null : id;
}
