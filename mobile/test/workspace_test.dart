import 'dart:convert';

import 'package:budget_studio/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries plans, item IDs and category icons into a clean month', () {
    final workspace = Workspace.empty('2026-11');
    final november = workspace.month('2026-11');
    final income = groupsOf(november).single;
    final salary = itemsOf(income).first;
    salary['amount'] = 2000.25;
    income['icon'] = 'bank';
    transactionsOf(november).add({
      'id': 'payment',
      'item': salary['id'],
      'amount': 1900.12,
      'date': '2026-11-01',
      'desc': 'Salary',
    });

    final december = workspace.month('2026-12');
    expect(december['carriedFrom'], '2026-11');
    expect(transactionsOf(december), isEmpty);
    final copied = groupsOf(december).single;
    expect(copied['icon'], 'bank');
    expect(itemsOf(copied).first['id'], salary['id']);
    expect(MonthTotals(december).plannedIncome, 200025);
    itemsOf(copied).first['amount'] = 99;
    expect(salary['amount'], 2000.25);
  });

  test('Ledger backup round-trips and counts linked savings only once', () {
    final source = jsonDecode('''
      {
        "onboardingComplete":true,
        "futureProperty":{"kept":true},
        "months":{"2026-11":{"groups":[
          {"id":"income","name":"Income","items":[{"id":"salary","name":"Salary","amount":1000}]},
          {"id":"fixed","name":"Housing","items":[{"id":"rent","name":"Rent","amount":500}]},
          {"id":"savings","name":"Savings","classification":"saving","icon":"piggy",
           "items":[{"id":"trip","name":"Trip","amount":200}]}
        ],"tx":[
          {"id":"a","date":"2026-11-01","item":"salary","amount":1000,"desc":""},
          {"id":"b","date":"2026-11-02","item":"rent","amount":550.01,"desc":""},
          {"id":"c","date":"2026-11-02","item":"trip","amount":180.02,"desc":""}
        ]}},
        "goals":[{"id":"goal","item":"trip","name":"Trip","target":900,"opening":40,"date":""}]
      }
      ''');
    final workspace = Workspace.parse(source);
    expect(workspace.data, source);
    final totals = MonthTotals(workspace.month('2026-11'));
    expect(totals.actualBalance, 26997);
    expect(totals.actualOutgoings, 73003);
    expect(totals.actualFor('saving'), 18002);
    expect(totals.healthScore, 93);
    expect(workspace.goalContributions(workspace.goals.single), 18002);
  });

  test('rejects bad backups before they can replace the current data', () {
    final workspace = Workspace.empty('2026-11');
    final month = workspace.month('2026-11');
    transactionsOf(month).add({
      'id': 'bad',
      'item': 'unknown',
      'amount': 10,
      'date': '2026-11-15',
      'desc': '',
    });
    expect(() => Workspace.parse(workspace.data), throwsFormatException);
    expect(() => Workspace.parse({'months': []}), throwsFormatException);
  });
}
