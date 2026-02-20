import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blog_app/screens/blog_list_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateBlogScreen extends StatefulWidget {
  const CreateBlogScreen({super.key});

  @override
  State<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends State<CreateBlogScreen> {
  final supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  final ImagePicker _picker =
      ImagePicker(); // For picking images from the gallery
  List<File> _selectedImages = []; // Holds the selected images as File objects

  bool _isLoading = false;
  String? _errorText;

  final Color wineColor = const Color(0xFF6F1D1B);

  // Pick multiple images from gallery and preview only
  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker
        .pickMultiImage(); // Opens the image picker to select multiple images from the gallery
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((e) => File(e.path)));
      });
    }
  }

  // Upload images to Supabase Storage
  Future<List<String>> _uploadImages(String blogId) async {
    List<String> imageUrls = [];

    for (final image in _selectedImages) {
      final fileName = '${blogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('blog-images').upload(fileName, image);

      final imageUrl = supabase.storage
          .from('blog-images')
          .getPublicUrl(fileName);

      imageUrls.add(imageUrl);
    }

    return imageUrls;
  }

  // Create blog with title, content, user_id, username and optional images
  Future<void> _createBlog() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      setState(() {
        _errorText = "Title and Content are required.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = supabase.auth.currentUser!;
      // Fetch username from profiles table
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      final username =
          profile?['username'] ??
          'Unknown'; // Get the username from the profiles table, defaulting to 'Unknown' if not found

      // Insert blog into blogs table
      final blogInsert = await supabase
          .from('blogs')
          .insert({
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'user_id': user.id,
            'username': username,
          })
          .select()
          .single();

      final blogId = blogInsert['id'];

      // Upload images if any
      if (_selectedImages.isNotEmpty) {
        final imageUrls = await _uploadImages(blogId);

        for (final url in imageUrls) {
          // Insert each image URL into the blog_images table linked to the blog_id
          await supabase.from('blog_images').insert({
            'blog_id': blogId,
            'image_url': url,
          });
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BlogListScreen()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blog created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorText = "Failed to create blog: $e";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Blog"),
        backgroundColor: wineColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              // Title TextField
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Blog Title',
                  labelStyle: TextStyle(color: wineColor),
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
              const SizedBox(height: 15),
              // Content TextField
              TextField(
                controller: _contentController,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: 'Blog Content',
                  labelStyle: TextStyle(color: wineColor),
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
                    vertical: 19,
                  ),
                ),
                cursorColor: wineColor,
              ),
              const SizedBox(height: 20),
              // Button to pick images from gallery
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: wineColor),
                onPressed: _pickImages,
                child: const Text(
                  "Add Pictures",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 15),
              // Preview of selected images
              if (_selectedImages.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _selectedImages.map((image) {
                    final index = _selectedImages.indexOf(image);
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            image,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // X button
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              // Display error message if any
              if (_errorText != null)
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wineColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _createBlog,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Create Blog",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
