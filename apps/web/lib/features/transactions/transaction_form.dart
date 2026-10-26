import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bento_card.dart';
import 'transaction.dart';
import 'transaction_repository.dart';
import '../google_connection/google_oauth.dart';
import '../google_connection/google_connection.dart';

class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({super.key, this.initial});
  final BudgetTransaction? initial;
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
  bool _uncertain = false;
  String? _saveError;
  final _draftId = const Uuid().v4();
  BudgetTransaction? _pending;
  late TransactionRepository _boundRepository;
  bool get _locked => _saving || _uncertain || !_boundRepository.canWrite;
  @override
  void initState() {
    super.initState();
    _boundRepository = ref.read(transactionRepositoryProvider);
    final choices =
        _boundRepository.ledgerMembers.where((m) => m.active).toList();
    _member =
        _boundRepository.actor?.id ?? (choices.isEmpty ? '' : choices.first.id);
    final selected = ref.read(selectedDayProvider);
    final now = ref.read(clockProvider)();
    _date = DateTime(
        selected.year, selected.month, selected.day, now.hour, now.minute);
    final t = widget.initial;
    if (t != null) {
      _amount.text = t.amount.toString();
      _merchant.text = t.merchant;
      _memo.text = t.memo;
      _type = t.type;
      _category = t.categoryId;
      _member = t.memberId.isEmpty ? t.member : t.memberId;
      _payment = t.paymentMethod;
      _date = t.occurredAt;
    }
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

  Future<void> _save() async {
    if (_saving ||
        (!_boundRepository.canWrite && !_uncertain) ||
        (!_uncertain && !_form.currentState!.validate())) {
      return;
    }
    final repository = _boundRepository;
    if (!identical(repository, ref.read(transactionRepositoryProvider))) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final person = repository.ledgerMembers.firstWhere((m) => m.id == _member);
    _pending ??= BudgetTransaction(
        id: widget.initial?.id ?? _draftId,
        revision: widget.initial?.revision ?? '',
        type: _type,
        amount: int.parse(_amount.text),
        occurredAt: _date,
        merchant: _merchant.text.trim(),
        memo: _memo.text.trim(),
        categoryId: _category,
        member: person.name,
        memberId: person.id,
        paymentMethod: _payment);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final controller = ref.read(transactionsProvider.notifier);
      if (widget.initial == null) {
        await controller.add(_pending!);
      } else {
        await controller.update(_pending!);
      }
      if (!mounted ||
          !identical(repository, ref.read(transactionRepositoryProvider))) {
        return;
      }
      ref.read(visibleMonthProvider.notifier).state =
          DateTime(_date.year, _date.month);
      ref.read(selectedDayProvider.notifier).state = _date;
      final message = repository.isDemo
          ? '거래를 저장했어요. 이 세션에서만 유지됩니다.'
          : repository.householdId != null
              ? '공동 가계부에 거래를 저장했어요.'
              : '거래를 저장했어요. Sheets 재조회까지 확인했습니다.';
      context.go('/');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      });
    } catch (failure) {
      final message = failure is ConnectionFailure
          ? failure.message
          : '저장하지 못했어요. 입력을 확인하고 다시 시도해 주세요.';
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = message;
          _uncertain = failure is ConnectionFailure && failure.uncertainWrite;
          if (!_uncertain) _pending = null;
        });
        if (failure is ConnectionFailure && failure.reauthenticate) {
          ref.read(googleConnectionProvider).invalidateSession();
        }
      }
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
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
          Text(widget.initial == null ? '새로운 기록' : '기록 수정',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('오늘의 소비도, 반가운 수입도.',
              style: TextStyle(color: AppColors.muted)),
          if (!_boundRepository.canWrite)
            Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(_boundRepository.householdId != null
                    ? '원장 연결을 확인한 뒤 다시 기록해 주세요.'
                    : '조회 전용 원장이에요. Google 공유 권한과 활성 Members 연결을 확인해 주세요.')),
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
              onSelectionChanged: _locked
                  ? null
                  : (values) => setState(() {
                        _type = values.first;
                        _category = _boundRepository.categoryCatalog
                            .firstWhere((c) => c.type == _type && c.enabled)
                            .id;
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
                    enabled: !_locked,
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
                    enabled: !_locked,
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
                      onPressed: _locked ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                          '${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}')),
                  OutlinedButton.icon(
                      onPressed: _locked ? null : _pickTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                          '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}')),
                ]),
                const SizedBox(height: 16),
                const Text('기록한 사람', style: TextStyle(color: AppColors.muted)),
                Wrap(
                    spacing: 8,
                    children: _boundRepository.ledgerMembers
                        .where((m) => m.active)
                        .map((member) => ChoiceChip(
                            label: Text(
                                memberLabel(
                                    member, _boundRepository.ledgerMembers),
                                overflow: TextOverflow.ellipsis),
                            selected: member.id == _member,
                            onSelected: _locked
                                ? null
                                : (_) => setState(() => _member = member.id)))
                        .toList()),
                const SizedBox(height: 16),
                const Text('결제수단', style: TextStyle(color: AppColors.muted)),
                Wrap(
                    spacing: 8,
                    children: paymentMethods
                        .map((method) => ChoiceChip(
                            label: Text(method),
                            selected: method == _payment,
                            onSelected: _locked
                                ? null
                                : (_) => setState(() => _payment = method)))
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
                        children: _boundRepository.categoryCatalog
                            .where((c) =>
                                c.type == _type &&
                                (c.enabled || c.id == _category))
                            .map((c) => SizedBox(
                                  width: (constraints.maxWidth - 16) / 3,
                                  child: CategoryTile(
                                      category: c,
                                      selected: c.id == _category,
                                      onTap: _locked
                                          ? null
                                          : () =>
                                              setState(() => _category = c.id)),
                                ))
                            .toList())),
              ])),
          const SizedBox(height: 16),
          TextFormField(
              controller: _memo,
              enabled: !_locked,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                  labelText: '메모 (선택)', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          if (_saveError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                    liveRegion: true,
                    child: Text(_saveError!,
                        style: const TextStyle(color: AppColors.expense)))),
          FilledButton.icon(
              key: const ValueKey('save'),
              onPressed: _saving || (!_boundRepository.canWrite && !_uncertain)
                  ? null
                  : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving
                  ? '저장 중…'
                  : _uncertain
                      ? '저장 결과 다시 확인'
                      : '기록 저장하기')),
          TextButton(onPressed: () => context.go('/'), child: const Text('취소')),
          Text(
              _boundRepository.isDemo
                  ? '샘플 모드 · 새로고침하면 추가한 기록이 초기화됩니다.'
                  : _boundRepository.householdId != null
                      ? '공동 가계부 · 같은 아이디로 로그인하면 기록을 다시 볼 수 있어요.'
                      : 'Sheets 모드 · 새로고침 후 로그인하고 같은 시트를 다시 연결하세요.',
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
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
            color: selected ? AppColors.accentSoft : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Column(children: [
                      Icon(category.icon,
                          color: selected ? AppColors.accent : AppColors.muted),
                      const SizedBox(height: 8),
                      Text(category.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  selected ? AppColors.accent : AppColors.ink,
                              fontSize: 12))
                    ])))),
      );
}
