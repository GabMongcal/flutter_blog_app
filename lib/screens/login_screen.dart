import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers hold input values from TextFields
  final emailOrUsernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  // Supabase client (already initialized in main.dart)
  final supabase = Supabase.instance.client;

  // Define a wine color theme to be used throughout the UI
  final Color wineColor = Color(0xFF6F1D1B); // Deep wine/red tone

  // Login function
  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      String input = emailOrUsernameController.text.trim();
      String email;
      if (input.contains('@')) {
        // Input contains '@', so treat it as an email address directly
        email = input;
      } else {
        // Input does not contain '@', so treat it as a username
        // Query the 'profiles' table to find the email linked to this username
        final data = await supabase
            .from('profiles')
            .select('email')
            .eq('username', input)
            .single();

        if (data['email'] == null) {
          throw Exception('Username not found');
        }

        email = data['email'] as String; // Extract email from query result
      }

      // Use the resolved email to sign in with password
      await supabase.auth.signInWithPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      // If successful, go to MainPage
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      // Show error message with wine-themed SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: Invalid email/username or password', // User-friendly error message // Removed raw error details ($e) for security and better UX
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: wineColor,
        ),
      );
    }

    // Reset loading state after attempt
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar
      appBar: AppBar(
        title: Text('Login', style: TextStyle(color: Colors.white)),
        backgroundColor: wineColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
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
                      // Email or Username input with wine-themed borders and label colors
                      TextField(
                        controller: emailOrUsernameController,
                        decoration: InputDecoration(
                          labelText: 'Email or Username',
                          labelStyle: TextStyle(
                            color: wineColor,
                          ), // Wine color label
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: wineColor,
                            ), // Wine color border when enabled
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
                      // Password input with matching wine-themed borders and labels
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: wineColor),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: wineColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: wineColor,
                              width:
                                  2, //increased border width on focus for better visual feedback
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        obscureText: true, // hides password text
                        cursorColor: wineColor,
                      ),

                      SizedBox(height: 24),
                      // Login button
                      ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: wineColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),

                      SizedBox(height: 12),
                      // Navigate to Register with subtle styling
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: Text(
                          'No account? Register',
                          style: TextStyle(
                            color: wineColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
