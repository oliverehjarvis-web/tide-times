import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TideTimesApp());
}

class TideTimesApp extends StatelessWidget {
  const TideTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>(
      create: (_) => ApiService(),
      child: MaterialApp(
        title: 'Tide Times - Cornwall',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
            surface: const Color(0xFF0a1628),
          ),
          scaffoldBackgroundColor: const Color(0xFF0a1628),
          cardTheme: CardTheme(
            color: const Color(0xFF132040),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0a1628),
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
          ),
          tabBarTheme: TabBarTheme(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF42A5F5),
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.white10),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
