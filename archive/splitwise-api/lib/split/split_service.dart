import '../splitwise/split_math.dart';
import '../splitwise/splitwise_api.dart';
import 'split_models.dart';

/// Creates the Splitwise expense. Used by the app and the floating card.
Future<SplitRecord> splitOnSplitwise({
  required SplitwiseApi api,
  required SplitTarget target,
  required int myUserId,
  required SplitPrompt prompt,
  required String currency,
}) async {
  switch (target.kind) {
    case TargetKind.group:
      await api.createGroupExpense(
        groupId: target.groupId!,
        costMinor: prompt.amountMinor,
        description: prompt.payee,
        currency: currency,
      );
    case TargetKind.friends:
      await api.createSharedExpense(
        shares: equalSplit(
          payerId: myUserId,
          participantIds: target.friendIds,
          totalMinor: prompt.amountMinor,
        ),
        costMinor: prompt.amountMinor,
        description: prompt.payee,
        currency: currency,
      );
  }
  return SplitRecord(
    txnId: prompt.txnId,
    label: target.label,
    amountMinor: prompt.amountMinor,
    description: prompt.payee,
    at: DateTime.now(),
    demo: api.isDemo,
  );
}
