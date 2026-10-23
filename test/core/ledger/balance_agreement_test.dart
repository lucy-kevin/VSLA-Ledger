import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';

import '../../helpers/test_database.dart';

/// The balance is added up in SQL, and what is owed on each loan is worked
/// out in Dart (`loanStatuses`). They are two copies of one rule, so this
/// test makes them answer the same question and fails if they ever drift.
void main() {
  late AppDatabase db;
  late LedgerRepository ledger;

  const groupId = 'group-1';
  const sarah = 'member-sarah';

  setUp(() {
    db = newTestDatabase();
    ledger = LedgerRepository(db: db, deviceId: 'phone-a');
  });
  tearDown(() => db.close());

  Future<void> expectBothAgree() async {
    final entries = await db.ledgerDao.getEntriesForMember(sarah);
    final owedInDart = loanStatuses(
      entries,
    ).fold<int>(0, (sum, status) => sum + status.owedUgx);

    final balance = await db.ledgerDao.watchMemberBalance(sarah).first;

    expect(balance.loansOutstandingUgx, owedInDart);
  }

  test('no loans', () async {
    await ledger.recordContribution(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 5000,
    );
    await expectBothAgree();
  });

  test('a loan part repaid', () async {
    final loan = await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 100000,
    );
    await ledger.recordRepayment(
      groupId: groupId,
      memberId: sarah,
      loanId: loan.id,
      amountUgx: 30000,
    );
    await expectBothAgree();
  });

  test('two loans, one fully repaid', () async {
    final first = await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 50000,
    );
    await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 70000,
    );
    await ledger.recordRepayment(
      groupId: groupId,
      memberId: sarah,
      loanId: first.id,
      amountUgx: 50000,
    );
    await expectBothAgree();
  });

  test('a cancelled repayment is owed again', () async {
    final loan = await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 80000,
    );
    final repayment = await ledger.recordRepayment(
      groupId: groupId,
      memberId: sarah,
      loanId: loan.id,
      amountUgx: 20000,
    );
    await ledger.cancelEntry(repayment.id);
    await expectBothAgree();
  });

  test('a cancelled loan, then the right one', () async {
    final wrong = await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 600000,
    );
    await ledger.cancelEntry(wrong.id);
    await ledger.issueLoan(
      groupId: groupId,
      memberId: sarah,
      amountUgx: 60000,
    );
    await expectBothAgree();
  });
}
