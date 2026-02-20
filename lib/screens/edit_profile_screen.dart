import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// EditProfileScreen implements a full-featured edit profile page.
/// Features:
/// - Fetches current user's profile (username, profile_pic) from Supabase
/// - Displays and allows editing of username and profile image
/// - Allows picking a new image from gallery, previews it, uploads to Supabase Storage,
///   and updates the profile_pic URL in the database
/// - Validates username uniqueness (excluding current user)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _usernameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  /// Shows a dialog with the profile picture in full size.
  void _showFullSizeProfilePic() {
    if (_profilePicUrl == null || _profilePicUrl!.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: true, // Allows closing dialog by tapping outside
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
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

  // State variables for profile data
  String?
  _profilePicUrl; // Stores the public URL of the profile image (saved image)
  String?
  _initialUsername; // The username fetched from the database (for uniqueness check)
  File?
  _pickedImageFile; // Stores the image file picked by the user for preview only (upload deferred)
  bool _isLoading = false; // Indicates if data is being loaded or saved
  String? _errorText; // For validation or upload error messages

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  /// Fetches the current user's profile (username, profile_pic) from the 'profiles' table.
  /// Sets initial values for username and profile picture.
  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = supabase.auth.currentUser;
      // If no authenticated user, clear profile info and stop loading.
      if (user == null) {
        setState(() {
          _errorText = "Not logged in.";
          _isLoading = false;
        });
        return;
      }
      // Query the 'profiles' table for the current user's profile data (username and profile_pic URL).
      final res = await supabase
          .from('profiles')
          .select('username, profile_pic')
          .eq('id', user.id)
          .single();
      // Set the fetched username and profile picture URL in the state to display in the UI.
      setState(() {
        _initialUsername = res['username'] as String?;
        _usernameController.text = _initialUsername ?? '';
        _profilePicUrl = res['profile_pic'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = "Failed to load profile: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    // Pick image from gallery
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return; // User cancelled picking an image
    setState(() {
      // Only set _pickedImageFile for preview; do NOT upload or update database here.
      _pickedImageFile = File(picked.path);
      _errorText = null;
    });
    // Note: Upload is deferred until save; preview is shown via _pickedImageFile
  }

  /// Uploads the given image file to Supabase Storage and returns the public URL.
  Future<String> _uploadImage(File imageFile) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in.");
    // Generate unique filename: user id + timestamp
    final filename = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath =
        filename; // Store directly in the bucket root (no subfolder)

    // Upload to Supabase Storage 'profile-images' bucket (root)
    await supabase.storage
        .from('profile-images')
        .upload(
          storagePath,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    // Get the public URL for the uploaded image
    final publicUrl = supabase.storage
        .from('profile-images')
        .getPublicUrl(storagePath);

    return publicUrl;
  }

  // Deletes the old profile image from Supabase Storage to prevent orphaned files.
  Future<void> _deleteOldImage(String oldImageUrl) async {
    try {
      final uri = Uri.parse(oldImageUrl);
      final filename = uri.pathSegments.last; // last segment is the filename
      if (filename.isEmpty) return;
      await supabase.storage.from('profile-images').remove([filename]);
      //print("Deleted old profile image: $filename");
    } catch (e) {
      //print("Failed to delete old profile image: $e");
    }
  }

  // Checks if the given username is unique (case-insensitive) among all users except the current user.
  Future<bool> _isUsernameUnique(String username) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    // Query for any user with this username, excluding current user
    final res = await supabase
        .from('profiles')
        .select('id')
        .ilike('username', username) // Case-insensitive match
        .neq('id', user.id);
    return (res as List)
        .isEmpty; // If empty, username is unique; otherwise, it's taken by another user.
  }

  /// Handles saving changes to the profile.
  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    // Validate username is not empty
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorText = "Username cannot be empty.";
      });
      return;
    }
    // If username changed, check for uniqueness
    if (username != _initialUsername) {
      final unique = await _isUsernameUnique(username);
      if (!unique) {
        setState(() {
          _isLoading = false;
          _errorText = "Username is already taken.";
        });
        return;
      }
    }
    // Proceed to save changes: upload new image if picked, then update profile data in the database.
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in.");

      String? newProfilePicUrl = _profilePicUrl;

      // If user picked a new image, upload it now and get the URL
      if (_pickedImageFile != null) {
        try {
          // Upload the new image and get its public URL
          final uploadedUrl = await _uploadImage(_pickedImageFile!);

          // After successful upload, delete the old profile picture from storage
          if (_profilePicUrl != null &&
              _profilePicUrl!.isNotEmpty &&
              _profilePicUrl != uploadedUrl) {
            await _deleteOldImage(_profilePicUrl!);
          }

          newProfilePicUrl = uploadedUrl;
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorText = "Image upload failed: $e";
          });
          return;
        }
      }

      // Prepare update data
      final updateData = {'username': username};
      // Only update profile_pic if a new image was uploaded
      if (_pickedImageFile != null) {
        updateData['profile_pic'] = newProfilePicUrl ?? '';
      }
      // Update the profiles table with new username and profile_pic URL if applicable.
      await supabase.from('profiles').update(updateData).eq('id', user.id);

      // Update the username in all blogs posted by this user
      await supabase
          .from('blogs')
          .update({'username': username})
          .eq('user_id', user.id);
      // After successful update, refresh the local state with new profile data to reflect changes in the UI.
      setState(() {
        _isLoading = false;
        _errorText = null;
        _initialUsername = username;
        _profilePicUrl = newProfilePicUrl;
        _pickedImageFile = null; // Clear picked image after successful save
      });
      // Show a snackbar or pop the screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = "Failed to save changes: $e";
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Builds the profile image widget based on the current state:
  Widget _buildProfileImage() {
    // If the user has picked a new image, show the local preview of that image (not yet uploaded).
    if (_pickedImageFile != null) {
      // Show preview of picked image (before upload)
      return CircleAvatar(
        radius: 56,
        backgroundImage: FileImage(_pickedImageFile!),
      );
      // If no new image is picked but there is an existing profile picture URL, show the image from that URL.
    } else if (_profilePicUrl != null && _profilePicUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          // Only show full size if profilePicUrl is valid
          if (_profilePicUrl != null && _profilePicUrl!.isNotEmpty) {
            _showFullSizeProfilePic();
          }
        },
        child: CircleAvatar(
          radius: 56,
          backgroundImage: NetworkImage(_profilePicUrl!),
        ),
      );
    } else {
      // Default avatar when no profile picture is set
      return const CircleAvatar(
        radius: 56,
        backgroundColor: Color.fromARGB(181, 111, 28, 27),
        child: Icon(Icons.person, size: 56, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wine color theme
    const wineColor = Color(0xFF6F1D1B);
    const wineLight = Color.fromARGB(255, 235, 203, 202);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: wineColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: wineLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile image preview (see _buildProfileImage)
                  Center(child: _buildProfileImage()),
                  const SizedBox(height: 16),
                  // Button to pick a new image from gallery
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: wineColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed:
                        _pickImage, // Trigger image picking from gallery when tapped.
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Change Profile Picture"),
                  ),
                  // Conditionally render the "Delete Profile Picture" button if a profile picture exists.
                  if (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB23A48),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Delete Profile Picture"),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                // Show confirmation dialog before deleting
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: const Text(
                                      'Are you sure you want to delete your profile picture?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                // If user confirmed, perform deletion
                                if (confirm == true) {
                                  setState(() {
                                    _isLoading = true;
                                    _errorText = null;
                                  });
                                  try {
                                    await _deleteOldImage(_profilePicUrl!);
                                    // Update the database to set profile_pic to null for the current user.
                                    await supabase
                                        .from('profiles')
                                        .update({'profile_pic': null})
                                        .eq(
                                          'id',
                                          supabase.auth.currentUser!.id,
                                        );
                                    // Clear the local state for profile picture to reflect deletion in the UI.
                                    setState(() {
                                      _profilePicUrl = null;
                                      _pickedImageFile = null;
                                      _isLoading = false;
                                    });

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Profile picture deleted.",
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isLoading = false;
                                      _errorText =
                                          "Failed to delete profile picture: $e";
                                    });
                                  }
                                }
                              },
                      ),
                    ),
                  const SizedBox(height: 32),
                  // TextField to edit username
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      labelStyle: const TextStyle(color: wineColor),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: wineColor, width: 2),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: wineColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Error message (if any)
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 15),
                      ),
                    ),
                  // Save Changes button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: wineColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _saveChanges,
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
