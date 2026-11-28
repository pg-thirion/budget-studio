import 'dart:convert';
import 'dart:math';

typedef Json = Map<String, dynamic>;

const classifications = {
  'income': 'Income',
  'need': 'Needs',
  'want': 'Wants',
  'saving': 'Savings & investments',
  'giving': 'Giving',
  'debt': 'Debt repayments',
  'other': 'Unclassified',
};

final _classPatterns = {
  'saving': RegExp(r'saving|invest|pension|retirement'),
  'want': RegExp(
    r'want|entertainment|leisure|hobby|takeaway|subscription|dining',
  ),
  'giving': RegExp(r'donat|giving|gift|charit'),
  'debt': RegExp(r'debt|loan|credit card'),
  'need': RegExp(
    r'housing|essential|rent|mortgage|utilit|food|grocery|groceries|transport|medical|health|insurance|fees|education|electricity',
  ),
};

String inferClassification(String name) {
  final lower = name.trim().toLowerCase();
  for (final entry in _classPatterns.entries) {
    if (entry.value.hasMatch(lower)) return entry.key;
  }
  return 'other';
}

String classificationOf(Json group) => group['name'] == 'Income'
    ? 'income'
    : (group['classification'] as String?) ??
          inferClassification(group['name'] as String);

List<Json> groupsOf(Json month) => (month['groups'] as List).cast<Json>();
List<Json> itemsOf(Json group) => (group['items'] as List).cast<Json>();
List<Json> transactionsOf(Json month) => (month['tx'] as List).cast<Json>();

Json? findGroup(Json month, Object? item) {
  for (final group in groupsOf(month)) {
    if (itemsOf(group).any((entry) => entry['id'] == item)) return group;
  }
  return null;
}

int cents(num amount) => (amount * 100).round();

int? parseAmount(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^(?:\d{1,12}(?:\.\d{0,2})?|\.\d{1,2})$').hasMatch(value)) {
    return null;
  }
  return cents(double.parse(value));
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String monthKey(DateTime date) => dateKey(date).substring(0, 7);
DateTime ledgerToday() => DateTime.now().toUtc().add(const Duration(hours: 2));

final _random = Random.secure();

String newId() {
  final bytes = List.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Json newItem(String name, [int value = 0]) => {
  'id': newId(),
  'name': name,
  'amount': value / 100,
};

Json _emptyMonth() => {
  'groups': <Json>[
    {
      'id': newId(),
      'name': 'Income',
      'items': [newItem('Salary (Post Tax)'), newItem('Other income')],
    },
  ],
  'tx': <Json>[],
};

final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool _number(Object? value, {bool positive = false}) =>
    value is num &&
    value.isFinite &&
    (value * 100).isFinite &&
    (positive ? value > 0 : value >= 0);

void _require(bool valid) {
  if (!valid) throw const FormatException('Invalid Ledger workspace');
}

class Workspace {
  Workspace._(this.data);

  factory Workspace.empty(String month) => Workspace._({
    'onboardingComplete': false,
    'months': {month: _emptyMonth()},
  });

  factory Workspace.parse(Object? value) {
    if (value is! Json) throw const FormatException('Invalid Ledger workspace');
    final onboarding = value['onboardingComplete'];
    _require(!value.containsKey('onboardingComplete') || onboarding is bool);
    final months = value['months'];
    if (months is! Json || months.isEmpty) {
      throw const FormatException('Invalid Ledger workspace');
    }
    for (final entry in months.entries) {
      final month = entry.value;
      if (!_monthPattern.hasMatch(entry.key) || month is! Json) {
        throw const FormatException('Invalid Ledger month');
      }
      final groups = month['groups'];
      final transactions = month['tx'];
      if (groups is! List || transactions is! List) {
        throw const FormatException('Invalid Ledger month');
      }
      final groupIds = <String>{};
      final itemIds = <String>{};
      int incomeGroups = 0;
      for (final group in groups) {
        if (group is! Json ||
            group['id'] is! String ||
            group['name'] is! String ||
            group['items'] is! List) {
          throw const FormatException('Invalid Ledger category');
        }
        _require(groupIds.add(group['id'] as String));
        if (group['name'] == 'Income') incomeGroups++;
        if (group.containsKey('classification')) {
          _require(
            group['classification'] != 'income' &&
                classifications.containsKey(group['classification']),
          );
        }
        _require(!group.containsKey('icon') || group['icon'] is String);
        for (final item in group['items'] as List) {
          if (item is! Json ||
              item['id'] is! String ||
              item['name'] is! String ||
              !_number(item['amount'])) {
            throw const FormatException('Invalid Ledger item');
          }
          _require(itemIds.add(item['id'] as String));
        }
      }
      _require(incomeGroups == 1);
      final transactionIds = <String>{};
      for (final tx in transactions) {
        if (tx is! Json ||
            tx['id'] is! String ||
            tx['date'] is! String ||
            tx['desc'] is! String ||
            !itemIds.contains(tx['item']) ||
            !_number(tx['amount'], positive: true)) {
          throw const FormatException('Invalid Ledger transaction');
        }
        final date = tx['date'] as String;
        _require(
          transactionIds.add(tx['id'] as String) && date.startsWith(entry.key),
        );
      }
    }
    if (value.containsKey('goals')) {
      final goals = value['goals'];
      if (goals is! List) throw const FormatException('Invalid Ledger goals');
      final ids = <String>{};
      final links = <String>{};
      for (final goal in goals) {
        if (goal is! Json ||
            goal['id'] is! String ||
            goal['item'] is! String ||
            goal['name'] is! String ||
            goal['date'] is! String ||
            !_number(goal['target'], positive: true) ||
            !_number(goal['opening'])) {
          throw const FormatException('Invalid Ledger savings goal');
        }
        final date = goal['date'] as String;
        _require(
          ids.add(goal['id'] as String) &&
              links.add(goal['item'] as String) &&
              (goal['name'] as String).trim().isNotEmpty &&
              (date.isEmpty || _datePattern.hasMatch(date)),
        );
      }
    }
    return Workspace._(value);
  }

  final Json data;
  Map<String, Json> get months => (data['months'] as Json).cast<String, Json>();
  List<Json> get goals => ((data['goals'] ??= <Json>[]) as List).cast<Json>();

  Json month(String key) {
    if (months[key] case final existing?) return existing;
    final previous =
        months.keys.where((month) => month.compareTo(key) < 0).toList()..sort();
    if (previous.isEmpty) return months[key] = _emptyMonth();
    final source = previous.last;
    return months[key] = {
      'groups': jsonDecode(jsonEncode(groupsOf(months[source]!))),
      'tx': <Json>[],
      'carriedFrom': source,
    };
  }

  int goalContributions(Json goal) {
    var total = 0;
    final item = goal['item'];
    for (final month in months.values) {
      final group = findGroup(month, item);
      if (group == null || classificationOf(group) != 'saving') continue;
      for (final tx in transactionsOf(month)) {
        if (tx['item'] == item) total += cents(tx['amount'] as num);
      }
    }
    return total;
  }
}

class GroupTotals {
  const GroupTotals(this.group, this.plan, this.actual);

  final Json group;
  final int plan;
  final int actual;

  String get kind => classificationOf(group);
  String get name => group['name'] as String;
}

class MonthTotals {
  MonthTotals(Json month) {
    for (final tx in transactionsOf(month)) {
      final item = tx['item'] as String;
      itemActual[item] = (itemActual[item] ?? 0) + cents(tx['amount'] as num);
    }
    groups = [
      for (final group in groupsOf(month))
        GroupTotals(
          group,
          itemsOf(
            group,
          ).fold(0, (total, item) => total + cents(item['amount'] as num)),
          itemsOf(
            group,
          ).fold(0, (total, item) => total + (itemActual[item['id']] ?? 0)),
        ),
    ];
  }

  final Map<String, int> itemActual = {};
  late final List<GroupTotals> groups;

  Iterable<GroupTotals> get expenses =>
      groups.where((group) => group.kind != 'income');
  int planFor(String kind) => groups
      .where((group) => group.kind == kind)
      .fold(0, (total, group) => total + group.plan);
  int actualFor(String kind) => groups
      .where((group) => group.kind == kind)
      .fold(0, (total, group) => total + group.actual);
  int get plannedIncome => planFor('income');
  int get actualIncome => actualFor('income');
  int get plannedOutgoings =>
      expenses.fold(0, (total, group) => total + group.plan);
  int get actualOutgoings =>
      expenses.fold(0, (total, group) => total + group.actual);
  int get actualBalance => actualIncome - actualOutgoings;

  Map<String, double> get healthFactors {
    if (actualIncome <= 0) return {};
    final savingPlan = planFor('saving');
    final savingActual = actualFor('saving');
    final spendPlan = plannedOutgoings - savingPlan;
    final overspend = expenses
        .where((group) => group.kind != 'saving')
        .fold(0, (total, group) => total + max(0, group.actual - group.plan));
    double points(num proportion) => 25 * proportion.clamp(0, 1).toDouble();
    return {
      'Cash flow': points(1 + actualBalance / actualIncome),
      'Budget discipline': points(
        spendPlan > 0
            ? 1 - overspend / spendPlan
            : overspend == 0
            ? 1
            : 0,
      ),
      'Savings rate': points(savingActual / actualIncome / .2),
      'Savings target': points(savingPlan > 0 ? savingActual / savingPlan : 0),
    };
  }

  int? get healthScore {
    final factors = healthFactors;
    return factors.isEmpty
        ? null
        : factors.values.reduce((a, b) => a + b).round();
  }
}
