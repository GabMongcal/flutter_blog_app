import 'package:flutter/material.dart';
import 'package:flutter_blog_app/screens/create_blog_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'blog_list_screen.dart';
import 'view_profile_screen.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to hold the username of the logged-in user.
  String? username;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  // Fetches the username of the currently authenticated user from the 'profiles' table.
  Future<void> _fetchUsername() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userId = user.id;

    // Query the 'profiles' table to get the username associated with the current user's id.
    final data = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .single();
    // Extract the username from the query result and update the state to display it in the UI.
    final fetchedUsername = data['username'] as String?;
    if (mounted) {
      setState(() {
        username = fetchedUsername;
      });
    }
  }

  // Confirmation dialog for logout to prevent accidental sign-outs.
  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false); // User cancelled logout
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.of(context).pop(true); // Confirm logout
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    // If the user confirmed logout, navigate back to the login screen and clear the navigation stack to prevent back navigation to authenticated screens.
    if (shouldLogout == true) {
      Navigator.pop(context);
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false, // remove all previous routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define color palette for consistent theming across the app.
    final wineColor = Color(0xFF6F1D1B);
    final peachColor = Color.fromARGB(255, 199, 133, 133);
    return Scaffold(
      key:
          _scaffoldKey, // Assign the scaffold key to control the endDrawer programmatically.
      appBar: AppBar(
        title: Text('Home', style: TextStyle(color: Colors.white)),
        backgroundColor: wineColor,
        actions: [
          IconButton(
            icon: Icon(
              Icons.menu,
              color: peachColor, //
            ),
            onPressed: () {
              // Open the endDrawer programmatically when the menu icon is tapped.
              _scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: 'Open menu',
          ),
        ],
      ),
      //endDrawer
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.7, // Limit drawer width
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: wineColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF6F1D1B)),
                title: const Text(
                  'View Profile',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () async {
                  Navigator.pop(context); // Close drawer
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ViewProfileScreen(),
                    ),
                  );
                  if (result == true) {
                    _fetchUsername(); // Refresh username in case it was updated in the profile screen.
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFF6F1D1B)),
                title: const Text('Log Out', style: TextStyle(fontSize: 16)),
                onTap: () async {
                  Navigator.pop(context); // Close drawer
                  _confirmLogout(context); // Show logout confirmation dialog
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Adding a large blog icon above the greeting text improves visual hierarchy
            Icon(Icons.article, size: 110, color: wineColor),
            Text(
              'Welcome, $username to Quiet Blogs!!',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            // Row of buttons for navigating to blog list and create blog screens.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wineColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BlogListScreen()),
                    );
                    // refresh username after returning from BlogListScreen in case of any profile updates that might affect the display.
                    if (result == true) {
                      await _fetchUsername();
                    }
                  },
                  child: Text(
                    'View Blogs',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wineColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateBlogScreen(),
                      ),
                    );
                    // Refresh username after returning from CreateBlogScreen
                    if (result == true) {
                      await _fetchUsername();
                    }
                  },
                  child: Text(
                    'Create Blog',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
