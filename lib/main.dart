import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screens/feed_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  final themeProvider = ThemeProvider(storage: storage);
  await themeProvider.loadTheme();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: NotepadApp(storage: storage),
    ),
  );
}

class NotepadApp extends StatelessWidget {
  final StorageService storage;

  const NotepadApp({required this.storage, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Notepad',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          home: FeedScreen(storage: storage),
        );
      },
    );
  }
}
