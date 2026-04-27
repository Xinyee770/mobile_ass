import 'package:flutter/material.dart';
import 'Authentication_UI/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jahawxshukwvqzmahwff.supabase.co',
    anonKey: 'sb_publishable_lEo1DkgG5eBoYRvsooloLg_oeLmU0ky',
  );
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Home(),
    );
  }
}