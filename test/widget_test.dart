// A basic smoke test for the Gym Tracker app.
//
// This verifies that the app's root widget can be constructed without errors.
// Full widget tests (database interactions, navigation) are planned for a later phase.

import 'package:flutter_test/flutter_test.dart';

import 'package:gym_tracker/main.dart';

void main() {
  testWidgets('GymTrackerApp can be constructed', (WidgetTester tester) async {
    // Build the root widget. Note: screens that access the database will
    // surface loading/error states here; this test only verifies the app
    // scaffolds and starts without throwing.
    await tester.pumpWidget(const GymTrackerApp());

    // Allow the first frame and any pending async work to settle.
    await tester.pump();

    // The app title should appear in the AppBar of MainScreen.
    expect(find.text('Gym Tracker'), findsWidgets);
  });
}