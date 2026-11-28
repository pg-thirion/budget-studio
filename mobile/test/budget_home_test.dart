import 'package:budget_studio/budget_home.dart';
import 'package:budget_studio/editors.dart';
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

  testWidgets('budget editor saves with large text above the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final month = monthKey(ledgerToday());
    final workspace = Workspace.empty(month);
    final group = groupsOf(workspace.month(month)).first;
    final item = itemsOf(group).first;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 140),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => editItem(context, group, item),
              child: const Text('Edit item'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit item'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final amount = find.widgetWithText(TextField, 'Monthly budget (ZAR)');
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '750.25');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(item['amount'], 750.25);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switches navigation at tablet width and retains the current page',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = Workspace.empty(monthKey(ledgerToday()));
      workspace.data['onboardingComplete'] = true;
      await tester.pumpWidget(
        MaterialApp(
          home: BudgetHome(
            workspace: workspace,
            status: 'Saved to cloud',
            onChanged: () {},
            onSave: () {},
            onReload: () {},
            onSignOut: () {},
            onTheme: () {},
          ),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(393, 852);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Budget planner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
