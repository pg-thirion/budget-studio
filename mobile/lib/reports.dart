import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'workspace.dart';

final _currency = NumberFormat.currency(
  locale: 'en_ZA',
  name: 'ZAR',
  symbol: 'R',
);
String zar(int value) => _currency.format(value / 100);
String monthName(String key) {
  final date = DateTime.tryParse('$key-01');
  return date == null ? key : DateFormat('MMMM yyyy').format(date);
}

String dayName(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat('d MMM yyyy').format(date);
}

const _palette = [
  Color(0xff6180b3),
  Color(0xff37a392),
  Color(0xffbf985e),
  Color(0xff7665b1),
  Color(0xffd68c7e),
  Color(0xff8593a5),
];

class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.amount, {super.key});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              zar(amount),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: amount < 0 ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final double value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 7,
        borderRadius: BorderRadius.circular(8),
        color: color,
        semanticsLabel: label,
      ),
    );
  }
}

List<Widget> overviewCards(
  BuildContext context,
  MonthTotals totals,
  ValueChanged<Json> openGroup,
  VoidCallback openBudget,
) {
  final theme = Theme.of(context);
  final expenses = totals.expenses.toList();
  final savePlan = totals.planFor('saving');
  final saved = totals.actualFor('saving');
  final remaining = totals.plannedIncome - totals.plannedOutgoings;
  final budgetRemaining = totals.plannedOutgoings - totals.actualOutgoings;
  final scale = expenses.fold(
    1,
    (value, group) => max(value, max(group.plan, group.actual)),
  );
  final allocationScale = max(
    1,
    max(totals.plannedIncome, totals.plannedOutgoings),
  );
  final score = totals.healthScore;
  final wants = totals.planFor('want');
  final excess =
      expenses
          .where((group) => group.kind != 'saving' && group.actual > group.plan)
          .toList()
        ..sort((a, b) => (b.actual - b.plan).compareTo(a.actual - a.plan));

  return [
    Container(
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 16),
      decoration: BoxDecoration(
        color: const Color(0xff152b40),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Actual balance',
            style: TextStyle(color: Color(0xffb8cddd)),
          ),
          const SizedBox(height: 5),
          Text(
            zar(totals.actualBalance),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: totals.actualBalance < 0
                  ? const Color(0xffffaab0)
                  : const Color(0xfff2fffb),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xff476175)),
          DefaultTextStyle.merge(
            style: const TextStyle(color: Color(0xffe8f3fb)),
            child: Column(
              children: [
                AmountRow('Recorded income', totals.actualIncome),
                AmountRow('Actual outgoings', totals.actualOutgoings),
              ],
            ),
          ),
        ],
      ),
    ),
    LedgerCard(
      title: 'Budget position',
      children: [
        AmountRow('Planned income', totals.plannedIncome),
        AmountRow('Planned outgoings', totals.plannedOutgoings),
        AmountRow('Unallocated income', remaining),
        AmountRow('Budget remaining', budgetRemaining),
        ProgressLine(
          value: totals.plannedOutgoings == 0
              ? 0
              : totals.actualOutgoings / totals.plannedOutgoings,
          label: 'Budget used',
          color: budgetRemaining < 0 ? theme.colorScheme.error : null,
        ),
      ],
    ),
    LedgerCard(
      title: 'Savings target',
      children: [
        AmountRow('Recorded contributions', saved),
        AmountRow('Monthly target', savePlan),
        ProgressLine(
          value: savePlan == 0 ? 0 : saved / savePlan,
          label: 'Savings target progress',
        ),
        Text(
          savePlan == 0
              ? 'Set a savings target in Budget.'
              : saved >= savePlan
              ? 'Target reached'
              : '${zar(savePlan - saved)} still to save',
        ),
      ],
    ),
    LedgerCard(
      title: 'Planned income allocation',
      children: [
        if (expenses.every((group) => group.plan == 0))
          const Text(
            'Add planned outgoings to see how you’ve allocated your income.',
          ),
        for (final (index, group) in expenses.indexed)
          if (group.plan > 0)
            InkWell(
              onTap: () => openGroup(group.group),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AmountRow(group.name, group.plan),
                  ProgressLine(
                    value: group.plan / allocationScale,
                    label: '${group.name} allocation',
                    color: _palette[index % _palette.length],
                  ),
                ],
              ),
            ),
        if (remaining > 0) AmountRow('Unallocated', remaining),
      ],
    ),
    LedgerCard(
      title: 'Planned vs actual',
      children: [
        if (expenses.isEmpty)
          const Text('Add an expense category in Budget to compare spending.'),
        for (final group in expenses)
          if (group.plan > 0 || group.actual > 0)
            InkWell(
              onTap: () => openGroup(group.group),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(group.name, style: theme.textTheme.titleSmall),
                    AmountRow('Planned', group.plan),
                    ProgressLine(
                      value: group.plan / scale,
                      label: '${group.name} planned',
                      color: _palette[0],
                    ),
                    AmountRow('Actual', group.actual),
                    ProgressLine(
                      value: group.actual / scale,
                      label: '${group.name} actual',
                      color: group.actual > group.plan && group.kind != 'saving'
                          ? theme.colorScheme.error
                          : _palette[1],
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
    LedgerCard(
      title: 'Spending by classification',
      children: [
        if (expenses.isEmpty)
          const Text('Your spending categories will appear here.'),
        for (final entry in classifications.entries)
          if (entry.key != 'income' &&
              (totals.planFor(entry.key) > 0 ||
                  totals.actualFor(entry.key) > 0)) ...[
            AmountRow(entry.value, totals.actualFor(entry.key)),
            Text(
              '${zar(totals.planFor(entry.key))} planned',
              style: theme.textTheme.bodySmall,
            ),
          ],
      ],
    ),
    LedgerCard(
      title: 'Budget insights',
      children: [
        if (totals.plannedIncome == 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set your planned income'),
            subtitle: const Text(
              'Add expected income to compare your planned allocations.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: openBudget,
          )
        else if (remaining < 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Balance your budget'),
            subtitle: Text(
              'Planned outgoings exceed income by ${zar(-remaining)}.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: openBudget,
          )
        else
          Text(
            '${(savePlan / totals.plannedIncome * 100).round()}% of planned income is allocated to savings.',
          ),
        if (wants > 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Review your wants budget'),
            subtitle: Text(
              'A 20% reduction would free ${zar((wants * .2).round())} per month.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: openBudget,
          ),
        if (excess.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Review ${excess.first.name}'),
            subtitle: Text(
              'Recorded spending is ${zar(excess.first.actual - excess.first.plan)} over plan.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openGroup(excess.first.group),
          ),
      ],
    ),
    LedgerCard(
      title: 'Monthly financial health',
      children: [
        if (score == null)
          const Text('Record income to calculate your monthly score.')
        else ...[
          Text(
            '$score / 100 · ${score >= 80
                ? 'Strong'
                : score >= 60
                ? 'Room to improve'
                : 'Needs attention'}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final factor in totals.healthFactors.entries) ...[
            Text('${factor.key} · ${factor.value.round()} / 25'),
            ProgressLine(value: factor.value / 25, label: factor.key),
          ],
          const SizedBox(height: 8),
          const Text(
            'A guide based on your budget and recorded transactions, with a 20% savings-rate benchmark.',
          ),
        ],
      ],
    ),
  ];
}

List<Widget> historyCards(Workspace workspace, ValueChanged<String> onMonth) {
  final months =
      workspace.months.entries
          .map((entry) => (key: entry.key, totals: MonthTotals(entry.value)))
          .toList()
        ..sort((a, b) => b.key.compareTo(a.key));
  final income = months.fold(
    0,
    (sum, month) => sum + month.totals.actualIncome,
  );
  final outgoings = months.fold(
    0,
    (sum, month) => sum + month.totals.actualOutgoings,
  );
  final scale = months
      .take(12)
      .fold(
        1,
        (maximum, month) => max(
          maximum,
          max(
            month.totals.actualBalance.abs(),
            (month.totals.plannedIncome - month.totals.plannedOutgoings).abs(),
          ),
        ),
      );
  return [
    LedgerCard(
      title: 'All months',
      children: [
        AmountRow('Actual income', income),
        AmountRow('Actual outgoings', outgoings),
        AmountRow('Total actual balance', income - outgoings),
      ],
    ),
    LedgerCard(
      title: 'Budget history',
      children: [
        for (final (index, month) in months.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(monthName(month.key)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (index < 12) ...[
                  AmountRow(
                    'Planned balance',
                    month.totals.plannedIncome - month.totals.plannedOutgoings,
                  ),
                  ProgressLine(
                    value:
                        (month.totals.plannedIncome -
                                month.totals.plannedOutgoings)
                            .abs() /
                        scale,
                    label: 'Planned balance',
                    color: _palette[0],
                  ),
                ],
                AmountRow('Actual balance', month.totals.actualBalance),
                if (index < 12)
                  ProgressLine(
                    value: month.totals.actualBalance.abs() / scale,
                    label: 'Actual balance',
                    color: _palette[1],
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onMonth(month.key),
          ),
      ],
    ),
  ];
}

List<Widget> annualCards(
  Workspace workspace,
  int year,
  ValueChanged<String> onMonth,
) {
  final months = {
    for (var i = 1; i <= 12; i++)
      monthKey(DateTime(year, i)):
          workspace.months[monthKey(DateTime(year, i))],
  };
  final recorded = {
    for (final entry in months.entries)
      if (entry.value != null && transactionsOf(entry.value!).isNotEmpty)
        entry.key: MonthTotals(entry.value!),
  };
  final totals = recorded.values;
  int sum(int Function(MonthTotals) value) =>
      totals.fold(0, (total, month) => total + value(month));
  final income = sum((month) => month.actualIncome);
  final expense = sum((month) => month.actualOutgoings);
  final savings = sum((month) => month.actualFor('saving'));
  final plan = sum((month) => month.planFor('saving'));
  final scale = totals.fold(
    1,
    (maximum, month) =>
        max(maximum, max(month.actualIncome, month.actualOutgoings)),
  );
  final scores = totals
      .map((month) => month.healthScore)
      .whereType<int>()
      .toList();
  return [
    LedgerCard(
      title: 'Recorded in $year',
      children: [
        Text('${recorded.length} of 12 months have recorded transactions.'),
        const SizedBox(height: 8),
        AmountRow('Actual income', income),
        AmountRow('Actual outgoings', expense),
        AmountRow('Savings contributions', savings),
        AmountRow('Actual balance', income - expense),
      ],
    ),
    LedgerCard(
      title: 'Outgoings by classification',
      children: [
        if (expense == 0) const Text('No recorded outgoings.'),
        for (final entry in classifications.entries)
          if (entry.key != 'income' &&
              sum((month) => month.actualFor(entry.key)) > 0)
            AmountRow(entry.value, sum((month) => month.actualFor(entry.key))),
      ],
    ),
    LedgerCard(
      title: 'Savings and financial health',
      children: [
        AmountRow('Savings contributions', savings),
        AmountRow('Target for recorded months', plan),
        ProgressLine(
          value: plan == 0 ? 0 : savings / plan,
          label: 'Annual savings progress',
        ),
        AmountRow(
          'Average saved per recorded month',
          totals.isEmpty ? 0 : (savings / totals.length).round(),
        ),
        if (scores.isNotEmpty)
          Text(
            'Average financial health: ${(scores.reduce((a, b) => a + b) / scores.length).round()} / 100',
          ),
      ],
    ),
    LedgerCard(
      title: 'Month-by-month',
      children: [
        for (final key in months.keys)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(monthName(key)),
            subtitle: switch (recorded[key]) {
              final total? => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProgressLine(
                    value: total.actualIncome / scale,
                    label: 'Actual income',
                    color: _palette[0],
                  ),
                  ProgressLine(
                    value: total.actualOutgoings / scale,
                    label: 'Actual outgoings',
                    color: _palette[2],
                  ),
                  Text(
                    'Income ${zar(total.actualIncome)} · Outgoings ${zar(total.actualOutgoings)}',
                  ),
                  Text('Savings ${zar(total.actualFor('saving'))}'),
                ],
              ),
              null => const Text('No recorded transactions'),
            },
            trailing: months[key] == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: months[key] == null ? null : () => onMonth(key),
          ),
      ],
    ),
  ];
}
