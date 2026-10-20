import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TransactionType { expense, income }

class BudgetCategory {
  const BudgetCategory(this.id, this.label, this.icon, this.type);
  final String id;
  final String label;
  final IconData icon;
  final TransactionType type;
}

const categories = [
  BudgetCategory(
      'food', '식비', Icons.restaurant_outlined, TransactionType.expense),
  BudgetCategory('groceries', '생활', Icons.shopping_basket_outlined,
      TransactionType.expense),
  BudgetCategory('cafe', '카페', Icons.coffee_outlined, TransactionType.expense),
  BudgetCategory('transport', '교통', Icons.directions_bus_outlined,
      TransactionType.expense),
  BudgetCategory(
      'shopping', '쇼핑', Icons.shopping_bag_outlined, TransactionType.expense),
  BudgetCategory(
      'health', '건강', Icons.favorite_border, TransactionType.expense),
  BudgetCategory(
      'leisure', '여가', Icons.weekend_outlined, TransactionType.expense),
  BudgetCategory('other', '기타', Icons.more_horiz, TransactionType.expense),
  BudgetCategory('salary', '급여', Icons.work_outline, TransactionType.income),
  BudgetCategory(
      'bonus', '부수입', Icons.savings_outlined, TransactionType.income),
];
const members = ['눈이', '딘이'];
const paymentMethods = ['카드', '현금', '계좌이체'];

class BudgetTransaction {
  const BudgetTransaction(
      {required this.id,
      required this.type,
      required this.amount,
      required this.occurredAt,
      required this.merchant,
      required this.categoryId,
      required this.member,
      this.memberId = '',
      this.memo = '',
      this.paymentMethod = '카드'});
  final String id;
  final TransactionType type;
  final int amount;
  final DateTime occurredAt;
  final String merchant;
  final String categoryId;
  final String member;
  final String memberId;
  final String memo;
  final String paymentMethod;
  BudgetCategory get category =>
      categories.firstWhere((c) => c.id == categoryId);
}

String won(int amount) => '₩${NumberFormat('#,###').format(amount)}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
int totalOf(Iterable<BudgetTransaction> items, TransactionType type) =>
    items.where((t) => t.type == type).fold(0, (sum, t) => sum + t.amount);

class LedgerMember {
  const LedgerMember(
      {required this.id,
      required this.name,
      this.subject = '',
      this.email = '',
      this.role = 'editor',
      this.active = true});
  final String id;
  final String name;
  final String subject;
  final String email;
  final String role;
  final bool active;
}

DateTime seoulTime(DateTime instant) {
  final d = instant.toUtc().add(const Duration(hours: 9));
  return DateTime(
      d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond);
}

String seoulIso(DateTime wallTime) =>
    '${DateTime.utc(wallTime.year, wallTime.month, wallTime.day, wallTime.hour, wallTime.minute, wallTime.second, wallTime.millisecond).toIso8601String().replaceFirst('Z', '')}+09:00';
String transactionMemberKey(BudgetTransaction t) =>
    t.memberId.isEmpty ? t.member : t.memberId;

String memberLabel(LedgerMember member, List<LedgerMember> people) {
  if (people.where((m) => m.name == member.name).length < 2) return member.name;
  return '${member.name} · ${member.email.isNotEmpty ? member.email : member.id.substring(0, 6)}';
}
