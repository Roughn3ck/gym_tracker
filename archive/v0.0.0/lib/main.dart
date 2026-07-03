import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/state/training_state.dart';
import 'package:gym_tracker/screens/main_screen.dart';

// Note: GymRepository is a plain class (not a ChangeNotifier), so it is
// registered via Provider. TrainingState extends ChangeNotifier and uses
// ChangeNotifierProvider.

void main() {
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (context) => GymRepository()),
        ChangeNotifierProvider(create: (context) => TrainingState()),
      ],
      child: MaterialApp(
        title: 'Gym Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}