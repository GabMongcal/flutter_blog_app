import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({Key? key}) : super(key: key);

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  /// Shows a dialog with the profile picture in full size.(preview)
  void _showFullSizeProfilePic() {
    if (_profilePicUrl == null || _profilePicUrl!.isEmpty)
      return; // No profile picture to show
    showDialog(
      context: context,
      barrierDismissible: true, // Allows closing dialog by tapping outside
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
            // Detects taps on the image to close the dialog
            onTap: () => Navigator.of(
              context,
            ).pop(), // Close dialog when tapping the image
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              // InteractiveViewer allows pinch-to-zoom and pan gestures.
              child: InteractiveViewer(
                child: Image.network(_profilePicUrl!, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }

  final SupabaseClient supabase = Supabase.instance.client;

  String? _username;
  String? _profilePicUrl;
  String? _email;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Fetch the profile data as soon as the screen is initialized.
    _fetchProfile();
  }

  // Fetches the profile information of the currently authenticated user from Supabase.
  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    // Get the currently authenticated user from Supabase Auth. If no user is authenticated, clear profile info and stop loading.
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        // If no authenticated user, clear profile info.
        setState(() {
          _username = null;
          _profilePicUrl = null;
          _email = null;
          _isLoading = false;
        });
        return;
      }

      // Fetch profile data from 'profiles' table using the user's id.
      final data = await supabase
          .from('profiles')
          .select('username, profile_pic')
          .eq('id', user.id)
          .single();

      setState(() {
        _username = data['username'] as String?;
        _profilePicUrl = data['profile_pic'] as String?;
        _email = user.email;
        _isLoading = false;
      });
    } catch (e) {
      // On exception, clear profile info and stop loading.
      setState(() {
        _username = null;
        _profilePicUrl = null;
        _email = supabase.auth.currentUser?.email;
        _isLoading = false;
      });
    }
  }

  /// Handles navigation to the EditProfileScreen.
  Future<void> _navigateToEditProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    // Refresh profile data after returning from EditProfileScreen.
    await _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    // Wine color palette consistent with Login and Edit Profile screens.
    const wineColor = Color(0xFF6F1D1B);
    const wineLight = Color.fromARGB(255, 235, 203, 202);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(
          context,
          true,
        ); // return true to trigger refresh on main page
        return false; // prevent default pop
      },
      child: Scaffold(
        // AppBar
        appBar: AppBar(
          backgroundColor: wineColor,
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        backgroundColor: wineLight,
        body:
            _isLoading // Show loading spinner while fetching profile data
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Center(
                // Center vertically and horizontally.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile picture or default icon.
                      GestureDetector(
                        onTap: // Only show full-size preview if there is a profile picture to display.
                        (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                            ? _showFullSizeProfilePic
                            : null,
                        child: CircleAvatar(
                          // Circular avatar for profile picture.
                          radius: 60,
                          backgroundColor: const Color.fromARGB(57, 0, 0, 0),
                          backgroundImage:
                              _profilePicUrl != null &&
                                  _profilePicUrl!.isNotEmpty
                              ? NetworkImage(_profilePicUrl!)
                              : null,
                          child: //
                          _profilePicUrl == null || _profilePicUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color.fromARGB(179, 105, 47, 47),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Username prominently displayed.
                      Text(
                        _username ?? 'No username',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Email displayed subtly, read-only.
                      Text(
                        _email ?? 'No email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Edit Profile button at the bottom.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _navigateToEditProfile, // Navigate to EditProfileScreen when tapped.
                          style: ElevatedButton.styleFrom(
                            backgroundColor: wineColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
