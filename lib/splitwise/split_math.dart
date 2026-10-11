import 'models.dart';

/// Payer pays the full amount; everyone (payer included) owes an equal part.
/// Leftover paise go one each to the first participants so shares always
/// add up to [totalMinor] exactly.
List<ExpenseShare> equalSplit({
  required int payerId,
  required List<int> participantIds,
  required int totalMinor,
}) {
  final ids = {payerId, ...participantIds}.toList();
  final base = totalMinor ~/ ids.length;
  final remainder = totalMinor % ids.length;
  return [
    for (var i = 0; i < ids.length; i++)
      ExpenseShare(
        userId: ids[i],
        paidMinor: ids[i] == payerId ? totalMinor : 0,
        owedMinor: base + (i < remainder ? 1 : 0),
      ),
  ];
}
