import 'package:flutter/material.dart';
import 'screens/costing_home_screen.dart';
import 'services/costing_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = CostingStore();
  await store.load();
  runApp(CostingStudio(store: store));
}

class CostingStudio extends StatelessWidget {
  const CostingStudio({super.key, required this.store});
  final CostingStore store;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF202426);
    const yellow = Color(0xFFF1C84C);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Costing Studio',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        colorScheme: ColorScheme.fromSeed(seedColor: ink, primary: ink, secondary: yellow,
          surface: Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F7F5),
          elevation: 0, scrolledUnderElevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDADDDD))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDADDDD))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ink, width: 1.6)),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          backgroundColor: ink, foregroundColor: Colors.white,
          minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      ),
      home: CostingHomeScreen(store: store),
    );
  }
}
