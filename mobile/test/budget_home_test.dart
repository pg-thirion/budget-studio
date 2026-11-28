import 'package:budget_studio/budget_home.dart';
import 'package:budget_studio/workspace.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plans income and records an actual transaction on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final month = monthKey(ledgerToday());
    final workspace = Workspace.empty(month);
    workspace.data['onboardingComplete'] = true;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetHome(
          workspace: workspace,
          status: 'Saved to cloud',
          onChanged: () => saves++,
          onSave: () {},
          onReload: () {},
          onSignOut: () {},
          onTheme: () {},
        ),
      ),
    );
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary (Post Tax)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly budget (ZAR)'),
      '1000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(MonthTotals(workspace.month(month)).plannedIncome, 100000);

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (ZAR)'),
      '950.50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(MonthTotals(workspace.month(month)).actualIncome, 95050);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });
}
