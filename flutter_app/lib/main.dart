import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/compass_state.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompassState(),
      child: MaterialApp(
        title: '天和鸿运质心罗盘',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
