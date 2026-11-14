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
    expect(find.text('Live Staging Board'), findsNothing);
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

    // Verify initial Home tab.
    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(navigation.selectedIndex, 0);

    // Navigate to My Garage.
    await tester.tap(find.byIcon(Icons.garage_outlined));
    await tester.pump();

    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(navigation.selectedIndex, 1);

    // Navigate to Events.
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pump();

    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(navigation.selectedIndex, 2);

    // Verify Events screen is displayed.
    expect(find.text('Events'), findsWidgets);

    // Navigate to Alerts.
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pump();

    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(navigation.selectedIndex, 3);

    // Navigate to More.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();

    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(navigation.selectedIndex, 4);
  });
}
