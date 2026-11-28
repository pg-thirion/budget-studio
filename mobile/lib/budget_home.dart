import 'dart:convert';

import 'package:file_selector/file_selector.dart' as files;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'editors.dart';
import 'reports.dart';
import 'workspace.dart';

enum _Page { overview, budget, transactions, goals, more }

class BudgetHome extends StatefulWidget {
  const BudgetHome({
    super.key,
    required this.workspace,
    required this.status,
    required this.onChanged,
    required this.onSave,
    required this.onReload,
    required this.onSignOut,
    required this.onTheme,
    this.onReplace,
  });

  final Workspace workspace;
  final String status;
  final VoidCallback onChanged, onSave, onReload, onSignOut, onTheme;
  final ValueChanged<Workspace>? onReplace;

  @override
  State<BudgetHome> createState() => _BudgetHomeState();
}

class _BudgetHomeState extends State<BudgetHome> {
  static const _titles = {
    _Page.overview: 'Monthly overview',
    _Page.budget: 'Budget planner',
    _Page.transactions: 'Transactions',
    _Page.goals: 'Savings goals',
    _Page.more: 'Reports & settings',
  };

  static const _classIcons = {
    'income': Icons.south_west_rounded,
    'need': Icons.home_outlined,
    'want': Icons.shopping_bag_outlined,
    'saving': Icons.savings_outlined,
    'giving': Icons.favorite_border,
    'debt': Icons.credit_card_outlined,
    'other': Icons.category_outlined,
  };

  static const _categoryIcons = {
    'wallet': Icons.account_balance_wallet_outlined,
    'income': Icons.south_west_rounded,
    'home': Icons.home_outlined,
    'food': Icons.shopping_basket_outlined,
    'dining': Icons.restaurant_outlined,
    'coffee': Icons.coffee_outlined,
    'car': Icons.directions_car_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'electricity': Icons.bolt_outlined,
    'water': Icons.water_drop_outlined,
    'phone': Icons.phone_android_outlined,
    'wifi': Icons.wifi,
    'health': Icons.medical_services_outlined,
    'shield': Icons.shield_outlined,
    'education': Icons.school_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'gift': Icons.card_giftcard,
    'piggy': Icons.savings_outlined,
    'invest': Icons.trending_up,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card_outlined,
    'game': Icons.sports_esports_outlined,
    'plane': Icons.flight_outlined,
    'pet': Icons.pets,
    'tools': Icons.build_outlined,
    'shirt': Icons.checkroom_outlined,
    'heart': Icons.favorite_border,
    'box': Icons.category_outlined,
  };

  late String _month;
  late int _year;
  _Page _page = _Page.overview;
  bool _annual = false;
  String _query = '', _filter = '';
  String? _groupId;
  bool _expandAll = false;
  int _expansionVersion = 0;

  Workspace get _workspace => widget.workspace;
  Json get _monthData => _workspace.month(_month);

  @override
  void initState() {
    super.initState();
    final today = ledgerToday();
    _month = monthKey(today);
    _year = today.year;
    _workspace.month(_month);
    if (_workspace.data['onboardingComplete'] == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _guide();
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  void _pageTo(_Page page, {String? groupId}) {
    setState(() {
      _page = page;
      _query = '';
      _filter = '';
      _groupId = groupId;
    });
  }

  void _setMonth(String key, {_Page? page}) {
    if (key.compareTo('1900-01') < 0 || key.compareTo('2199-12') > 0) return;
    final added = !_workspace.months.containsKey(key);
    _workspace.month(key);
    setState(() {
      _month = key;
      _query = '';
      _filter = '';
      _groupId = null;
      if (page != null) _page = page;
    });
    if (added) widget.onChanged();
  }

  String _offsetMonth(int count) {
    final current = DateTime.parse('$_month-01');
    return monthKey(DateTime(current.year, current.month + count));
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guide() async {
    final openBudget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Ledger'),
        content: const SingleChildScrollView(
          child: Text(
            'Start in Budget with expected income and outgoings.\n\n'
            'Record what you actually receive or spend in Transactions. '
            'Link a savings item to a goal to track its contributions over time.\n\n'
            'Ledger saves changes to your private cloud workspace.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open budget'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (_workspace.data['onboardingComplete'] == false) {
      _workspace.data['onboardingComplete'] = true;
      _changed();
    }
    if (openBudget == true) _pageTo(_Page.budget);
  }

  Future<void> _importBackup() async {
    try {
      final file = await files.openFile(
        acceptedTypeGroups: const [
          files.XTypeGroup(
            label: 'Ledger JSON backup',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 20 * 1024 * 1024) {
        _message('This backup exceeds the 20 MB import limit.');
        return;
      }
      final backup = Workspace.parse(jsonDecode(await file.readAsString()));
      if (!mounted) return;
      if (await _confirm(
            'Replace this budget?',
            'This replaces every month and savings goal in your cloud workspace. Export a backup first if you need the current data.',
            'Replace budget',
          ) &&
          mounted) {
        widget.onReplace?.call(backup);
      }
    } catch (_) {
      _message('Could not import a valid Ledger JSON backup.');
    }
  }

  Future<void> _exportBackup(BuildContext anchor) async {
    try {
      final box = anchor.findRenderObject()! as RenderBox;
      final fileName = 'ledger-backup-${dateKey(ledgerToday())}.json';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(
                const JsonEncoder.withIndent('  ').convert(_workspace.data),
              ),
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      _message('Could not share the backup.');
    }
  }

  Future<void> _category([Json? group]) async {
    if (await editCategory(context, _workspace, _month, group)) _changed();
  }

  Future<void> _item(Json group, [Json? item]) async {
    if (await editItem(context, group, item)) _changed();
  }

  Future<void> _transaction([Json? transaction]) async {
    if (groupsOf(_monthData).every((group) => itemsOf(group).isEmpty)) {
      _message('Add a budget item before recording a transaction.');
      return;
    }
    if (await editTransaction(
      context,
      _monthData,
      _month,
      transaction: transaction,
    )) {
      _changed();
    }
  }

  Future<void> _goal([Json? goal]) async {
    if (await editGoal(context, _workspace, _month, goal)) _changed();
  }

  Future<void> _contribute(Json goal) async {
    final month = _monthData;
    final itemId = goal['item'] as String;
    final group = findGroup(month, itemId);
    if (group != null) {
      if (classificationOf(group) != 'saving') {
        _message('Move the linked item to a savings category first.');
      } else if (await editTransaction(
        context,
        month,
        _month,
        itemId: itemId,
      )) {
        _changed();
      }
      return;
    }
    if (!await _confirm(
          'Add linked savings item?',
          'Add ${goal['name']} to this month to record a contribution.',
          'Continue',
        ) ||
        !mounted) {
      return;
    }
    final draft = jsonDecode(jsonEncode(month)) as Json;
    final savings = ensureSavingsGroup(draft);
    itemsOf(savings).add({'id': itemId, 'name': goal['name'], 'amount': 0});
    if (await editTransaction(context, draft, _month, itemId: itemId) &&
        mounted) {
      _workspace.months[_month] = draft;
      _changed();
    }
  }

  Future<void> _removeItem(Json group, Json item) async {
    final id = item['id'];
    if (transactionsOf(_monthData).any((entry) => entry['item'] == id) ||
        _workspace.goals.any((goal) => goal['item'] == id)) {
      _message(
        'Remove or reassign linked transactions and savings goals first.',
      );
      return;
    }
    if (await _confirm(
          'Delete budget item?',
          'Remove ${item['name']} from this month.',
          'Delete',
        ) &&
        mounted) {
      itemsOf(group).remove(item);
      _changed();
    }
  }

  Future<void> _removeGroup(Json group) async {
    final ids = itemsOf(group).map((item) => item['id']).toSet();
    if (transactionsOf(
          _monthData,
        ).any((entry) => ids.contains(entry['item'])) ||
        _workspace.goals.any((goal) => ids.contains(goal['item']))) {
      _message(
        'Remove or reassign linked transactions and savings goals first.',
      );
      return;
    }
    if (await _confirm(
          'Delete category?',
          'Remove ${group['name']} and its items from this month.',
          'Delete',
        ) &&
        mounted) {
      groupsOf(_monthData).remove(group);
      _changed();
    }
  }

  Widget _monthBar() {
    final months =
        {
              ..._workspace.months.keys,
              for (var i = -12; i <= 12; i++) _offsetMonth(i),
            }
            .where(
              (key) =>
                  key.compareTo('1900-01') >= 0 &&
                  key.compareTo('2199-12') <= 0,
            )
            .toList()
          ..sort();
    return Card(
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: _month == '1900-01'
                ? null
                : () => _setMonth(_offsetMonth(-1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _month,
                isExpanded: true,
                alignment: Alignment.center,
                items: [
                  for (final key in months)
                    DropdownMenuItem(
                      value: key,
                      alignment: Alignment.center,
                      child: Text(
                        monthName(key),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (key) {
                  if (key != null) _setMonth(key);
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: _month == '2199-12'
                ? null
                : () => _setMonth(_offsetMonth(1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _search(String label) => TextField(
    key: ValueKey((label, _month, _groupId)),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.search),
    ),
    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
  );

  Widget _filterField(Map<String, String> choices, String label) =>
      DropdownButtonFormField<String>(
        key: ValueKey((label, _month, _groupId)),
        initialValue: _filter,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: [
          for (final entry in choices.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) => setState(() => _filter = value ?? ''),
      );

  List<Widget> _budget(MonthTotals totals) {
    final groups = totals.groups
        .where(
          (group) =>
              (_groupId == null || _groupId == group.group['id']) &&
              (_filter.isEmpty || group.kind == _filter) &&
              [
                group.name,
                ...itemsOf(group.group).map((entry) => entry['name']),
              ].join(' ').toLowerCase().contains(_query),
        )
        .toList();
    return [
      if (_monthData['carriedFrom'] case final String previous)
        Text('Budget carried forward from ${monthName(previous)}.'),
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => setState(() {
                _expandAll = !_expandAll;
                _expansionVersion++;
              }),
              icon: Icon(_expandAll ? Icons.unfold_less : Icons.unfold_more),
              label: Text(_expandAll ? 'Collapse all' : 'Expand all'),
            ),
          ),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _category,
              icon: const Icon(Icons.add),
              label: const Text('Expense category'),
            ),
          ),
        ],
      ),
      if (_groupId != null)
        OutlinedButton(
          onPressed: () => _pageTo(_Page.budget),
          child: const Text('Show all categories'),
        ),
      _search('Search categories and items'),
      _filterField({
        '': 'All categories',
        ...classifications,
      }, 'Classification'),
      if (groups.isEmpty) const Text('No matching categories.'),
      for (final group in groups) _budgetGroup(group, totals),
      if (_groupId == null &&
          _filter.isEmpty &&
          _query.isEmpty &&
          totals.expenses.isEmpty)
        const LedgerCard(
          title: 'Plan your outgoings',
          children: [
            Text(
              'Add an expense category for needs, wants, savings or other outgoings.',
            ),
          ],
        ),
    ];
  }

  Widget _budgetGroup(GroupTotals group, MonthTotals totals) {
    final data = group.group;
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        key: ValueKey((_month, data['id'], _expansionVersion, _groupId)),
        initiallyExpanded:
            _expandAll ||
            _groupId != null ||
            (_expansionVersion == 0 && group.kind == 'income'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(
          _categoryIcons[data['icon']] ?? _classIcons[group.kind],
          color: theme.colorScheme.primary,
        ),
        title: Text(group.name, style: theme.textTheme.titleMedium),
        subtitle: Text(classifications[group.kind]!),
        children: [
          AmountRow('Planned', group.plan),
          AmountRow(
            group.kind == 'income' ? 'Received' : 'Actual',
            group.actual,
          ),
          ProgressLine(
            value: group.plan == 0
                ? (group.actual > 0 ? 1 : 0)
                : group.actual / group.plan,
            label: '${group.name} budget progress',
            color:
                group.actual > group.plan &&
                    group.kind != 'income' &&
                    group.kind != 'saving'
                ? theme.colorScheme.error
                : null,
          ),
          for (final item in itemsOf(data))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item['name'] as String),
              subtitle: Text(
                '${zar(cents(item['amount'] as num))} planned · ${zar(totals.itemActual[item['id']] ?? 0)} actual',
              ),
              onTap: () => _item(data, item),
              trailing: IconButton(
                tooltip: 'Delete ${item['name']}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeItem(data, item),
              ),
            ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _item(data),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
              TextButton(
                onPressed: () => _category(data),
                child: const Text('Edit category'),
              ),
              if (group.kind != 'income')
                TextButton(
                  onPressed: () => _removeGroup(data),
                  child: const Text('Delete category'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _transactions(MonthTotals totals) {
    final month = _monthData;
    const choices = {
      '': 'All transactions',
      'income': 'Income',
      'outgoing': 'Outgoings',
      'saving': 'Savings',
    };
    final visible = <Widget>[];
    final ordered = [...transactionsOf(month)]
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    for (final tx in ordered) {
      final group = findGroup(month, tx['item'])!;
      final kind = classificationOf(group);
      final item = itemsOf(
        group,
      ).firstWhere((item) => item['id'] == tx['item']);
      final description = tx['desc'] as String;
      final date = tx['date'] as String;
      if (![
            _filter.isEmpty,
            _filter == kind,
            _filter == 'outgoing' && kind != 'income',
          ].contains(true) ||
          ![
            description,
            item['name'],
            group['name'],
            date,
          ].join(' ').toLowerCase().contains(_query)) {
        continue;
      }
      final amount = cents(tx['amount'] as num);
      visible.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(_classIcons[kind]),
          title: Text(
            description.isEmpty ? item['name'] as String : description,
          ),
          subtitle: Text(
            '${dayName(date)} · ${item['name']}\n${kind == 'income' ? '+' : '−'}${zar(amount)}',
          ),
          onTap: () => _transaction(tx),
          trailing: IconButton(
            tooltip: 'Delete transaction',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirm(
                    'Delete transaction?',
                    'Remove this amount from the recorded totals.',
                    'Delete',
                  ) &&
                  mounted) {
                transactionsOf(month).remove(tx);
                _changed();
              }
            },
          ),
        ),
      );
    }
    return [
      LedgerCard(
        title: 'Recorded this month',
        children: [
          AmountRow('Income', totals.actualIncome),
          AmountRow('Outgoings', totals.actualOutgoings),
          AmountRow('Actual balance', totals.actualBalance),
        ],
      ),
      _search('Search transactions'),
      _filterField(choices, 'Transaction type'),
      LedgerCard(
        title: 'Activity',
        children: [
          if (visible.isEmpty) const Text('No matching transactions.'),
          ...visible,
        ],
      ),
    ];
  }

  List<Widget> _goals() {
    final goals = _workspace.goals;
    var target = 0, saved = 0, completed = 0;
    final cards = <Widget>[];
    for (final goal in goals) {
      final opening = cents(goal['opening'] as num);
      final contributions = _workspace.goalContributions(goal);
      final goalTarget = cents(goal['target'] as num);
      final value = contributions + opening;
      final linked = findGroup(_monthData, goal['item']);
      final date = goal['date'] as String;
      target += goalTarget;
      saved += value;
      if (value >= goalTarget) completed++;
      cards.add(
        LedgerCard(
          title: goal['name'] as String,
          children: [
            AmountRow('Saved', value),
            AmountRow('Target', goalTarget),
            ProgressLine(
              value: goalTarget == 0 ? 0 : value / goalTarget,
              label: 'Goal progress',
            ),
            if (value < goalTarget)
              AmountRow('Remaining', goalTarget - value)
            else
              const Text('Target reached'),
            if (date.isNotEmpty) Text('Target date · ${dayName(date)}'),
            AmountRow('Opening savings', opening),
            AmountRow('Recorded contributions', contributions),
            if (linked != null)
              Text(
                'Linked to ${itemsOf(linked).firstWhere((item) => item['id'] == goal['item'])['name']}',
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                FilledButton.tonal(
                  onPressed: () => _contribute(goal),
                  child: const Text('Contribution'),
                ),
                TextButton(
                  onPressed: () => _goal(goal),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () async {
                    if (await _confirm(
                          'Remove savings goal?',
                          'The linked budget item and transactions stay in your budget.',
                          'Remove',
                        ) &&
                        mounted) {
                      goals.remove(goal);
                      _changed();
                    }
                  },
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return [
      FilledButton.icon(
        onPressed: _goal,
        icon: const Icon(Icons.add),
        label: const Text('New savings goal'),
      ),
      if (goals.isEmpty)
        const LedgerCard(
          title: 'Set your first savings goal',
          children: [
            Text(
              'Choose a target and link it to a savings item to track contributions.',
            ),
          ],
        )
      else ...[
        LedgerCard(
          title: 'Savings goals',
          children: [
            AmountRow('Total targets', target),
            AmountRow('Saved towards goals', saved),
            Text('$completed of ${goals.length} goals reached'),
          ],
        ),
        ...cards,
      ],
    ];
  }

  List<Widget> _reports() {
    final months = _workspace.months.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final years = {
      for (final month in months) int.parse(month.substring(0, 4)),
      _year,
    }.toList()..sort((a, b) => b.compareTo(a));
    return [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('History'),
            icon: Icon(Icons.history),
          ),
          ButtonSegment(
            value: true,
            label: Text('Annual'),
            icon: Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {_annual},
        onSelectionChanged: (values) => setState(() => _annual = values.single),
      ),
      if (_annual) ...[
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: const InputDecoration(labelText: 'Year'),
          items: [
            for (final year in years)
              DropdownMenuItem(value: year, child: Text('$year')),
          ],
          onChanged: (year) {
            if (year != null) setState(() => _year = year);
          },
        ),
        ...annualCards(
          _workspace,
          _year,
          (key) => _setMonth(key, page: _Page.overview),
        ),
      ] else ...[
        LedgerCard(
          title: 'Workspace',
          children: [
            Semantics(liveRegion: true, child: Text(widget.status)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Save now'),
              onTap: widget.onSave,
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload cloud budget'),
              onTap: widget.onReload,
            ),
            Builder(
              builder: (context) => ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Export JSON backup'),
                onTap: () => _exportBackup(context),
              ),
            ),
            if (widget.onReplace != null)
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Import JSON backup'),
                onTap: _importBackup,
              ),
            ListTile(
              leading: const Icon(Icons.contrast),
              title: const Text('Switch appearance'),
              onTap: widget.onTheme,
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Budgeting guide'),
              onTap: _guide,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: widget.onSignOut,
            ),
          ],
        ),
        ...historyCards(
          _workspace,
          (key) => _setMonth(key, page: _Page.overview),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final totals = MonthTotals(_monthData);
    final content = switch (_page) {
      _Page.overview => overviewCards(
        context,
        totals,
        (group) => _pageTo(_Page.budget, groupId: group['id'] as String),
        () => _pageTo(_Page.budget),
      ),
      _Page.budget => _budget(totals),
      _Page.transactions => _transactions(totals),
      _Page.goals => _goals(),
      _Page.more => _reports(),
    };
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.space_dashboard_outlined),
        label: 'Overview',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        label: 'Budget',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Activity',
      ),
      NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'Goals'),
      NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
    ];
    void selectDestination(int index) => _pageTo(_Page.values[index]);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ledger.',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Workspace and saving',
            onPressed: () => _pageTo(_Page.more),
            icon: Icon(
              widget.status.startsWith('Saved')
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                backgroundColor: theme.colorScheme.surface,
                selectedIndex: _page.index,
                labelType: NavigationRailLabelType.all,
                scrollable: true,
                onDestinationSelected: selectDestination,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            Expanded(
              key: const ValueKey('budget-content'),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    key: PageStorageKey(_page),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 92),
                    children: [
                      Text(
                        _titles[_page]!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_page != _Page.more) ...[
                        const SizedBox(height: 10),
                        _monthBar(),
                      ],
                      if (_page != _Page.more &&
                          widget.status.startsWith('Save failed'))
                        TextButton(
                          onPressed: widget.onSave,
                          child: Text(widget.status),
                        ),
                      if (_page != _Page.more &&
                          widget.status.startsWith('Cloud conflict'))
                        TextButton(
                          onPressed: () => _pageTo(_Page.more),
                          child: Text(widget.status),
                        ),
                      for (final child in content)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: child,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _page == _Page.more || _page == _Page.goals
          ? null
          : FloatingActionButton(
              onPressed: _transaction,
              tooltip: 'Add transaction',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _page.index,
              onDestinationSelected: selectDestination,
              destinations: destinations,
            ),
    );
  }
}
