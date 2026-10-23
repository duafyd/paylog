import '../transactions/transaction.dart';

// Quoting alone does not prevent spreadsheet formula injection.
String csvCell(Object value) {
  var text = value.toString();
  if (RegExp(r'^[\s\uFEFF]*[=+@-]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r')) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

String ledgerCsv(List<BudgetTransaction> items) => '\uFEFF${[
      ['ID', '구분', '금액', '서울 거래시각', '사용처', '카테고리', '사용자', '결제수단', '메모'],
      ...items.map((t) => [
            t.id,
            t.type.name,
            t.amount,
            seoulIso(t.occurredAt),
            t.merchant,
            t.category.label,
            t.member,
            t.paymentMethod,
            t.memo
          ]),
    ].map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n';
