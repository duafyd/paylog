import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import 'transaction.dart';
import 'transaction_repository.dart';

class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({super.key});
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _memo = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = 'food';
  String _member = members.first;
  String _payment = paymentMethods.first;
  late DateTime _date;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final selected = ref.read(selectedDayProvider);
    final now = ref.read(clockProvider)();
    _date = DateTime(
        selected.year, selected.month, selected.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200, 12, 31));
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(
        picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(
        _date.year, _date.month, _date.day, picked.hour, picked.minute));
  }

  void _save() {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      ref.read(transactionsProvider.notifier).add(BudgetTransaction(
            id: const Uuid().v4(),
            type: _type,
            amount: int.parse(_amount.text),
            occurredAt: _date,
            merchant: _merchant.text.trim(),
            memo: _memo.text.trim(),
            categoryId: _category,
            member: _member,
            paymentMethod: _payment,
          ));
      ref.read(visibleMonthProvider.notifier).state =
          DateTime(_date.year, _date.month);
      ref.read(selectedDayProvider.notifier).state = _date;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('거래를 저장했어요. 이 세션에서만 유지됩니다.')));
        }
      });
    } catch (_) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했어요. 입력을 확인하고 다시 시도해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) => Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('새로운 기록', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('오늘의 소비도, 반가운 수입도.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('지출'),
                    icon: Icon(Icons.remove)),
                ButtonSegment(
                    value: TransactionType.income,
                    label: Text('수입'),
                    icon: Icon(Icons.add)),
              ],
              selected: {
                _type
              },
              onSelectionChanged: (values) => setState(() {
                    _type = values.first;
                    _category =
                        categories.firstWhere((c) => c.type == _type).id;
                  })),
          const SizedBox(height: 20),
          BentoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('금액', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                TextFormField(
                    key: const ValueKey('amount'),
                    controller: _amount,
                    style: AppTheme.numberStyle
                        .copyWith(fontSize: 32, fontWeight: FontWeight.w700),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12)
                    ],
                    decoration: const InputDecoration(
                        prefixText: '₩ ',
                        hintText: '0',
                        labelText: '거래 금액',
                        floatingLabelBehavior: FloatingLabelBehavior.always),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '');
                      return amount == null || amount <= 0
                          ? '1원 이상의 금액을 입력해 주세요.'
                          : null;
                    }),
              ])),
          const SizedBox(height: 16),
          BentoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SectionHeader('거래 정보'),
                const SizedBox(height: 16),
                TextFormField(
                    key: const ValueKey('merchant'),
                    controller: _merchant,
                    maxLength: 60,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                        labelText:
                            _type == TransactionType.income ? '수입 내역' : '사용처',
                        hintText: '어떤 기록인가요?'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '내역을 입력해 주세요.'
                        : null),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                          '${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}')),
                  OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                          '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}')),
                ]),
                const SizedBox(height: 16),
                const Text('기록한 사람', style: TextStyle(color: AppColors.muted)),
                Wrap(
                    spacing: 8,
                    children: members
                        .map((member) => ChoiceChip(
                            label: Text(member),
                            selected: member == _member,
                            onSelected: (_) =>
                                setState(() => _member = member)))
                        .toList()),
                const SizedBox(height: 16),
                const Text('결제수단', style: TextStyle(color: AppColors.muted)),
                Wrap(
                    spacing: 8,
                    children: paymentMethods
                        .map((method) => ChoiceChip(
                            label: Text(method),
                            selected: method == _payment,
                            onSelected: (_) =>
                                setState(() => _payment = method)))
                        .toList()),
              ])),
          const SizedBox(height: 16),
          BentoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SectionHeader('카테고리'),
                const SizedBox(height: 16),
                LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .where((c) => c.type == _type)
                            .map((c) => SizedBox(
                                  width: (constraints.maxWidth - 16) / 3,
                                  child: CategoryTile(
                                      category: c,
                                      selected: c.id == _category,
                                      onTap: () =>
                                          setState(() => _category = c.id)),
                                ))
                            .toList())),
              ])),
          const SizedBox(height: 16),
          TextFormField(
              controller: _memo,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                  labelText: '메모 (선택)', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          FilledButton.icon(
              key: const ValueKey('save'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? '저장 중…' : '기록 저장하기')),
          TextButton(onPressed: () => context.go('/'), child: const Text('취소')),
          const Text('샘플 모드 · 새로고침하면 추가한 기록이 초기화됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ));
}

class CategoryTile extends StatelessWidget {
  const CategoryTile(
      {super.key,
      required this.category,
      required this.selected,
      required this.onTap});
  final BudgetCategory category;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
            color: selected ? AppColors.tealSoft : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Column(children: [
                      Icon(category.icon,
                          color: selected ? AppColors.teal : AppColors.muted),
                      const SizedBox(height: 8),
                      Text(category.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: selected ? AppColors.teal : AppColors.ink,
                              fontSize: 12))
                    ])))),
      );
}
