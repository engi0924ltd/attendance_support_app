import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/common/menu_selection_screen.dart';

void main() async {
  // アプリの準備
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語の日付表示の準備
  await initializeDateFormatting('ja_JP');

  // アプリを起動
  runApp(
    const ProviderScope(
      child: AttendanceSupportApp(),
    ),
  );
}

class AttendanceSupportApp extends StatelessWidget {
  const AttendanceSupportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B型施設 支援者サポートアプリ',
      // 日本語ローカライゼーション設定
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      locale: const Locale('ja', 'JP'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      // 最初に表示する画面
      home: const MenuSelectionScreen(),
    );
  }
}
