import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  final supabase = Supabase
      .instance
      .client; // Supabase client (already initialized in main.dart)

  Future<void> register() async {
    // Color themes
    final wineColor = Color(0xFF6F1D1B);

    // Confirm password validation: ensure password and confirm password match
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: wineColor, // Wine color for SnackBar background
        ),
      );
      return;
    }
    // Username uniqueness check: query the 'profiles' table to see if the entered username already exists
    final existing = await supabase
        .from('profiles')
        .select('id')
        .eq('username', usernameController.text.trim())
        .limit(1)
        .maybeSingle(); // Check if a profile with the same username already exists in the 'profiles' table
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username already exists'),
          backgroundColor: wineColor,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true; // Show loading spinner while processing registration
    });

    try {
      // Create new user with email and password using Supabase Auth
      await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = supabase.auth.currentUser;

      if (user != null) {
        // Insert a new row into 'profiles' table with user ID, username, and email
        await supabase.from('profiles').insert({
          'id': user.id, // User ID from Supabase Auth
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
        });
      }

      // After successful signup and profile creation, go back to login screen
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: wineColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: wineColor,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Color theme
    final wineColor = Color(0xFF6F1D1B);

    return Scaffold(
      appBar: AppBar(
        title: Text('Register', style: TextStyle(color: Colors.white)),
        backgroundColor: wineColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quiet Pages',
                style: TextStyle(
                  fontSize: 32,
                  color: wineColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              // Username TextField
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: wineColor), // Wine color label
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: wineColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: wineColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                cursorColor: wineColor,
              ),

              SizedBox(height: 16),
              // Email TextField
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: wineColor), // Wine color label
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                    ), // Wine color border when enabled
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                      width: 2,
                    ), // Wine color border on focus
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                cursorColor: wineColor,
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 16),
              // Password TextField
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: wineColor), // Wine color label
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                    ), // Wine color border when enabled
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                      width: 2,
                    ), // Wine color border on focus
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                obscureText: true,
                cursorColor: wineColor,
              ),

              SizedBox(height: 16),

              // Confirm Password TextField
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: wineColor), // Wine color label
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                    ), // Wine color border when enabled
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: wineColor,
                      width: 2,
                    ), // Wine color border on focus
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                obscureText: true,
                cursorColor: wineColor,
              ),

              SizedBox(height: 32),

              ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: wineColor, // Wine color button background
                  minimumSize: Size(double.infinity, 48),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Register',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
