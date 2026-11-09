import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndrl/screens/app_shell.dart';
import 'package:ndrl/services/auth_service.dart';
import 'package:ndrl/services/device_service.dart';

void main() {
  testWidgets('NDRL app displays home dashboard', (tester) async {
    final deviceService = DeviceService();
    final authService = AuthService(deviceService: deviceService);

    addTearDown(() {
      authService.dispose();
      deviceService.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        home: NdrlAppShell(authService: authService),
      ),
    );

    expect(find.text('NDRL MOBILE'), findsOneWidget);
    expect(find.text('Live Staging Board'), findsOneWidget);
    expect(find.text('Season Points'), findsOneWidget);
    expect(find.text('Fantasy Racing'), findsOneWidget);
    expect(find.text('NDRL Members'), findsOneWidget);
    expect(find.text('Our Sponsors'), findsOneWidget);
  });

  testWidgets('NDRL bottom navigation works', (tester) async {
    final deviceService = DeviceService();
    final authService = AuthService(deviceService: deviceService);

    addTearDown(() {
      authService.dispose();
      deviceService.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        home: NdrlAppShell(authService: authService),
      ),
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
