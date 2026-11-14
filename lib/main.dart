import 'package:flutter/material.dart';

import 'src/config.dart';
import 'src/screens/events_screen.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.init();
  runApp(const TicketingApp());
}

class TicketingApp extends StatelessWidget {
  const TicketingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticketing',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const EventsScreen(),
    );
  }
}
