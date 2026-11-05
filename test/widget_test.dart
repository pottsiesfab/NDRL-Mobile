import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndrl/screens/app_shell.dart';

void main() {
  testWidgets('NDRL app displays home dashboard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(themeMode: ThemeMode.dark, home: NdrlAppShell()),
    );

    expect(find.text('NDRL MOBILE'), findsOneWidget);
    expect(find.text('Live Staging Board'), findsOneWidget);
    expect(find.text('Season Points'), findsOneWidget);
    expect(find.text('Fantasy Racing'), findsOneWidget);
    expect(find.text('Driver Profiles'), findsOneWidget);
    expect(find.text('Our Sponsors'), findsOneWidget);
  });

  testWidgets('NDRL bottom navigation works', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(themeMode: ThemeMode.dark, home: NdrlAppShell()),
    );

    // Navigate to Staging.
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pump();

    // Verify the Staging tab is selected.
    final stagingNavigation = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(stagingNavigation.selectedIndex, 1);

    // Navigate to Events.
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pump();

    final eventsNavigation = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(eventsNavigation.selectedIndex, 2);

    // Verify the Events screen is displayed.
    expect(find.text('Events'), findsWidgets);
  });
}
