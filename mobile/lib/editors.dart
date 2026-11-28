import 'package:material_ui/material_ui.dart';

import 'workspace.dart';

const _iconNames = <String, String>{
  'wallet': 'Wallet',
  'income': 'Income',
  'home': 'Home',
  'food': 'Groceries',
  'dining': 'Dining',
  'coffee': 'Coffee',
  'car': 'Car',
  'fuel': 'Fuel',
  'electricity': 'Electricity',
  'water': 'Water',
  'phone': 'Phone',
  'wifi': 'Internet',
  'health': 'Health',
  'shield': 'Insurance',
  'education': 'Education',
  'shopping': 'Shopping',
  'gift': 'Gifts',
  'piggy': 'Savings',
  'invest': 'Investments',
  'bank': 'Bank',
  'card': 'Debt / fees',
  'game': 'Entertainment',
  'plane': 'Travel',
  'pet': 'Pets',
  'tools': 'Maintenance',
  'shirt': 'Clothing',
  'heart': 'Giving',
  'box': 'Other',
};

Future<bool?> _showEditor(BuildContext context, WidgetBuilder builder) async {
  final route = DialogRoute<bool>(context: context, builder: builder);
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}

Json ensureSavingsGroup(Json month) {
  for (final group in groupsOf(month)) {
    if (classificationOf(group) == 'saving') return group;
  }
  final names = groupsOf(
    month,
  ).map((group) => (group['name'] as String).toLowerCase()).toSet();
  var name = 'Savings';
  for (var index = 2; names.contains(name.toLowerCase()); index++) {
    name = 'Savings $index';
  }
  final group = <String, dynamic>{
    'id': newId(),
    'name': name,
    'classification': 'saving',
    'icon': 'piggy',
    'items': <Json>[],
  };
  groupsOf(month).add(group);
  return group;
}

Future<bool> editCategory(
  BuildContext context,
  Workspace workspace,
  String month, [
  Json? group,
]) async {
  final model = workspace.month(month);
  final name = TextEditingController(text: group?['name'] as String? ?? '');
  var classification = group == null ? 'other' : classificationOf(group);
  var icon = _iconNames.containsKey(group?['icon'])
      ? group!['icon'] as String
      : group?['name'] == 'Income'
      ? 'income'
      : 'box';
  String? error;
  final result = await _showEditor(
    context,
    (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          group == null
              ? 'New category'
              : group['name'] == 'Income'
              ? 'Customise income'
              : 'Edit category',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                enabled: group?['name'] != 'Income',
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 12),
              if (group?['name'] != 'Income')
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: classification == 'income'
                      ? 'other'
                      : classification,
                  decoration: const InputDecoration(
                    labelText: 'Classification',
                  ),
                  items: classifications.entries
                      .where((entry) => entry.key != 'income')
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => classification = value ?? classification),
                ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: _iconNames.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => icon = value ?? icon),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = name.text.trim();
              if (value.isEmpty) {
                setState(() => error = 'Enter a category name.');
                return;
              }
              if (groupsOf(model).any(
                (other) =>
                    other['id'] != group?['id'] &&
                    (other['name'] as String).toLowerCase() ==
                        value.toLowerCase(),
              )) {
                setState(() => error = 'That category already exists.');
                return;
              }
              if (group != null &&
                  group['name'] != 'Income' &&
                  classification != 'saving' &&
                  workspace.goals.any(
                    (goal) => itemsOf(
                      group,
                    ).any((item) => item['id'] == goal['item']),
                  )) {
                setState(
                  () => error = 'This category has a linked savings goal.',
                );
                return;
              }
              if (group == null) {
                groupsOf(model).add({
                  'id': newId(),
                  'name': value,
                  'classification': classification,
                  'icon': icon,
                  'items': <Json>[newItem('New item')],
                });
              } else {
                if (group['name'] != 'Income') {
                  group['name'] = value;
                  group['classification'] = classification;
                }
                group['icon'] = icon;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  return result ?? false;
}

Future<bool> editItem(BuildContext context, Json group, [Json? item]) async {
  final name = TextEditingController(text: item?['name'] as String? ?? '');
  final amount = TextEditingController(
    text: item == null ? '0.00' : (item['amount'] as num).toStringAsFixed(2),
  );
  String? error;
  final result = await _showEditor(
    context,
    (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(item == null ? 'New budget item' : 'Edit budget item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              decoration: const InputDecoration(
                labelText: 'Monthly budget (ZAR)',
                prefixText: 'R ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = name.text.trim();
              final cents = parseAmount(amount.text);
              if (value.isEmpty || cents == null) {
                setState(() => error = 'Enter a name and a valid amount.');
                return;
              }
              if (itemsOf(group).any(
                (other) =>
                    other['id'] != item?['id'] &&
                    (other['name'] as String).toLowerCase() ==
                        value.toLowerCase(),
              )) {
                setState(
                  () => error = 'An item with that name already exists.',
                );
                return;
              }
              if (item == null) {
                itemsOf(group).add(newItem(value, cents));
              } else {
                item['name'] = value;
                item['amount'] = cents / 100;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  amount.dispose();
  return result ?? false;
}

Future<bool> editTransaction(
  BuildContext context,
  Json month,
  String key, {
  Json? transaction,
  String? itemId,
}) async {
  final items = [for (final group in groupsOf(month)) ...itemsOf(group)];
  if (items.isEmpty) return false;
  final desc = TextEditingController(
    text: transaction?['desc'] as String? ?? '',
  );
  final amount = TextEditingController(
    text: transaction == null
        ? ''
        : (transaction['amount'] as num).toStringAsFixed(2),
  );
  final currentItem =
      items.any((item) => item['id'] == (transaction?['item'] ?? itemId))
      ? (transaction?['item'] ?? itemId) as String
      : items.first['id'] as String;
  var selectedItem = currentItem;
  final first = DateTime.parse('$key-01');
  final last = DateTime(first.year, first.month + 1, 0);
  final today = ledgerToday();
  final parsed = DateTime.tryParse(transaction?['date'] as String? ?? '');
  var date = parsed != null && monthKey(parsed) == key
      ? parsed
      : monthKey(today) == key
      ? DateTime(today.year, today.month, today.day)
      : first;
  String? error;
  final result = await _showEditor(
    context,
    (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          transaction == null ? 'New transaction' : 'Edit transaction',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedItem,
                decoration: const InputDecoration(labelText: 'Budget item'),
                items: [
                  for (final group in groupsOf(month))
                    for (final entry in itemsOf(group))
                      DropdownMenuItem(
                        value: entry['id'] as String,
                        child: Text(
                          '${group['name']} · ${entry['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: itemId != null
                    ? null
                    : (value) =>
                          setState(() => selectedItem = value ?? selectedItem),
              ),
              TextField(
                controller: amount,
                decoration: const InputDecoration(
                  labelText: 'Amount (ZAR)',
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(dateKey(date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: date.isBefore(first) || date.isAfter(last)
                        ? first
                        : date,
                    firstDate: first,
                    lastDate: last,
                  );
                  if (chosen != null && context.mounted) {
                    setState(() => date = chosen);
                  }
                },
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final cents = parseAmount(amount.text);
              if (cents == null || cents <= 0) {
                setState(() => error = 'Enter an amount greater than zero.');
                return;
              }
              final row = transaction ?? <String, dynamic>{'id': newId()};
              row.addAll({
                'date': dateKey(date),
                'item': selectedItem,
                'amount': cents / 100,
                'desc': desc.text.trim(),
              });
              if (transaction == null) transactionsOf(month).add(row);
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  desc.dispose();
  amount.dispose();
  return result ?? false;
}

Future<bool> editGoal(
  BuildContext context,
  Workspace workspace,
  String month, [
  Json? goal,
]) async {
  final name = TextEditingController(text: goal?['name'] as String? ?? '');
  final target = TextEditingController(
    text: goal == null ? '' : (goal['target'] as num).toStringAsFixed(2),
  );
  final opening = TextEditingController(
    text: goal == null ? '0.00' : (goal['opening'] as num).toStringAsFixed(2),
  );
  final model = workspace.month(month);
  final linkedIds = workspace.goals.map((entry) => entry['item']).toSet();
  final available = <String, String>{};
  for (final monthData in [model, ...workspace.months.values]) {
    for (final group in groupsOf(
      monthData,
    ).where((group) => classificationOf(group) == 'saving')) {
      for (final item in itemsOf(
        group,
      ).where((item) => !linkedIds.contains(item['id']))) {
        available.putIfAbsent(
          item['id'] as String,
          () => '${group['name']} ? ${item['name']}',
        );
      }
    }
  }
  String? selected = goal?['item'] as String?;
  DateTime? targetDate = DateTime.tryParse(goal?['date'] as String? ?? '');
  String? error;
  final result = await _showEditor(
    context,
    (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(goal == null ? 'New savings goal' : 'Edit savings goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Goal name'),
              ),
              TextField(
                controller: target,
                decoration: const InputDecoration(
                  labelText: 'Target amount (ZAR)',
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: opening,
                decoration: const InputDecoration(
                  labelText: 'Already saved (ZAR)',
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (goal == null)
                DropdownButtonFormField<String>(
                  initialValue: '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Savings item'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Create a dedicated savings item',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final entry in available.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => selected = value == '' ? null : value,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(
                  targetDate == null ? 'No date' : dateKey(targetDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final today = ledgerToday();
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: targetDate ?? today,
                    firstDate: DateTime(1),
                    lastDate: DateTime(9999, 12, 31),
                  );
                  if (chosen != null && context.mounted) {
                    setState(() => targetDate = chosen);
                  }
                },
              ),
              if (targetDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => targetDate = null),
                    child: const Text('Clear date'),
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = name.text.trim();
              final targetCents = parseAmount(target.text);
              final openingCents = parseAmount(opening.text);
              if (title.isEmpty ||
                  targetCents == null ||
                  targetCents <= 0 ||
                  openingCents == null) {
                setState(
                  () => error =
                      'Enter a name, positive target and valid saved amount.',
                );
                return;
              }
              if (workspace.goals.any(
                (entry) =>
                    entry['id'] != goal?['id'] &&
                    (entry['name'] as String).toLowerCase() ==
                        title.toLowerCase(),
              )) {
                setState(() => error = 'A goal with that name already exists.');
                return;
              }
              if (selected == null) {
                final group = ensureSavingsGroup(model);
                final item = newItem(title);
                itemsOf(group).add(item);
                selected = item['id'] as String;
              }
              final row = goal ?? <String, dynamic>{'id': newId()};
              row.addAll({
                'item': selected,
                'name': title,
                'target': targetCents / 100,
                'opening': openingCents / 100,
                'date': targetDate == null ? '' : dateKey(targetDate!),
              });
              if (goal == null) workspace.goals.add(row);
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  target.dispose();
  opening.dispose();
  return result ?? false;
}
