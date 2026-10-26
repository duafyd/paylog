/// Only the supported Hana approval format is eligible for automatic import.
/// Cancellation/unknown messages stay in the review inbox.
class HanaPayment {
  const HanaPayment(
      this.card, this.amount, this.merchant, this.occurredAt, this.cancelled);
  final String card, merchant;
  final int amount;
  final DateTime occurredAt; // UTC
  final bool cancelled;
}

HanaPayment? parseHana(String body, DateTime received) {
  if (body.isEmpty || body.length > 4096) return null;
  final text = body.replaceAll('\r', '').trim();
  final card = RegExp(r'하나[\d*]{4,12}').firstMatch(text)?.group(0);
  final event =
      RegExp(r'(?:^|\n)(승인취소|취소|승인)(?:\s|$)').firstMatch(text)?.group(1) ??
          RegExp(r'하나[\d*]{4,12}(승인취소|취소|승인)').firstMatch(text)?.group(1);
  if (card == null || event == null) return null;
  final clean = text.replaceAll(RegExp(r'누적[^\n]*'), '');
  final amount = int.tryParse(
      (RegExp(r'(?:금액\s*)?([\d,]+)원').firstMatch(clean)?.group(1) ?? '')
          .replaceAll(',', ''));
  final time = RegExp(r'(\d{1,2})/(\d{1,2})\s*(\d\d):(\d\d)').firstMatch(clean);
  if (amount == null || amount <= 0 || amount > 999999999999 || time == null) {
    return null;
  }
  final merchant =
      RegExp(r'사용처\s+([^\n]+)').firstMatch(clean)?.group(1)?.trim() ??
          clean.substring(time.end).split('\n').first.trim();
  if (merchant.isEmpty || merchant.length > 120) return null;
  final month = int.parse(time[1]!),
      day = int.parse(time[2]!),
      hour = int.parse(time[3]!),
      minute = int.parse(time[4]!);
  if (month < 1 || month > 12 || day < 1 || hour > 23 || minute > 59) {
    return null;
  }
  final year = received.toUtc().add(const Duration(hours: 9)).year;
  final candidates = <DateTime>[];
  for (final y in [year - 1, year, year + 1]) {
    final local = DateTime.utc(y, month, day, hour, minute);
    if (local.month == month && local.day == day) {
      candidates.add(local.subtract(const Duration(hours: 9)));
    }
  }
  candidates.sort((a, b) =>
      a.difference(received).abs().compareTo(b.difference(received).abs()));
  if (candidates.isEmpty ||
      candidates.first.difference(received).abs() > const Duration(days: 7)) {
    return null;
  }
  return HanaPayment(card, amount, merchant, candidates.first, event != '승인');
}
