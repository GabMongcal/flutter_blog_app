// main.dart

import 'package:flutter/material.dart'; // Flutter UI library
import 'package:flutter_blog_app/screens/login_screen.dart';
import 'package:flutter_blog_app/screens/main_page.dart'; // MainPage screen
import 'package:flutter_blog_app/screens/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required for async init

  await Supabase.initialize(
    url: 'https://zjsbgzvarbjhxbjvmmzc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpqc2JnenZhcmJqaHhianZtbXpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2ODQ0OTQsImV4cCI6MjA4NTI2MDQ5NH0.jx35GyGxzIy1EJpJa-YaFQqYvkyPNYj_WxdReGn4pjo',
  );

  runApp(MyApp());
}

// Root widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/main': (context) => MainPage(),
      },
    );
  }
}

/// AuthGate widget determines which screen to show based on authentication status.(MainPage if logged in, or LoginScreen if not).

class AuthGate extends StatelessWidget {
  // Async method to get current session
  Future<Session?> _getSession() async {
    // Supabase client stores session persistently and retrieves it asynchronously
    return Supabase.instance.client.auth.currentSession;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session?>(
      future: _getSession(),
      builder: (context, snapshot) {
        // While waiting for the auth session check, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If an error occurred, show login screen as fallback
        if (snapshot.hasError) {
          return LoginScreen();
        }

        final session = snapshot.data;

        // If session exists, user is logged in -> go to MainPage
        if (session != null) {
          return MainPage();
        }

        // No session means user is not logged in -> go to LoginScreen
        return LoginScreen();
      },
    );
  }
}
