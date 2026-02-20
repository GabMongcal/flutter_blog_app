import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditBlogScreen extends StatefulWidget {
  final Map<String, dynamic> blog;

  const EditBlogScreen({super.key, required this.blog});

  @override
  State<EditBlogScreen> createState() => _EditBlogScreenState();
}

class _EditBlogScreenState extends State<EditBlogScreen> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<String> existingImages =
      []; // URLs of images already associated with the blog
  List<File> newImages = []; // New images picked by the user (not yet uploaded)
  List<String> imagesToDelete = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.blog['title'] ?? '';
    _contentController.text = widget.blog['content'] ?? '';
    existingImages = (widget.blog['images'] as List?)?.cast<String>() ?? [];
  }

  // Pick multiple images from gallery and preview only
  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        newImages.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _deleteExistingImage(String imageUrl) async {
    // Mark image for deletion
    setState(() {
      existingImages.remove(imageUrl); // remove from UI immediately
      imagesToDelete.add(imageUrl); // store for deletion on save
    });
  }

  Future<void> _deleteAllImages() async {
    setState(() {
      imagesToDelete.addAll(existingImages); // mark all for deletion
      existingImages.clear(); // remove from UI
    });
  }

  Future<void> _saveChanges() async {
    setState(() => isLoading = true);

    try {
      // Update title and content
      await supabase
          .from('blogs')
          .update({
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
          })
          .eq('id', widget.blog['id']);

      // Delete images that were marked for deletion from storage and database
      for (final imageUrl in imagesToDelete) {
        final uri = Uri.parse(imageUrl);
        final filePath = uri.pathSegments.last;

        await supabase.storage.from('blog-images').remove([filePath]);

        // Also remove the image record from the 'blog_images' table
        await supabase
            .from('blog_images')
            .delete()
            .eq('blog_id', widget.blog['id'])
            .eq('image_url', imageUrl);
      }

      // Upload new images
      for (final image in newImages) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';

        await supabase.storage.from('blog-images').upload(fileName, image);

        final publicUrl = supabase.storage
            .from('blog-images')
            .getPublicUrl(fileName);

        await supabase.from('blog_images').insert({
          'blog_id': widget.blog['id'],
          'image_url': publicUrl,
        });
      }

      if (!mounted) return;

      // Show success snackbar before going back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blog updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Return true so blog list screen can refresh
      Navigator.pop(context, true);
    } catch (e) {
      // Show error snackbar if something goes wrong during update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update blog. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color wineColor = Color(0xFF6F1D1B);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false; // prevent default pop
      },
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Edit Blog', style: TextStyle(color: Colors.white)),
          backgroundColor: wineColor,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Title',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6F1D1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
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
                  const SizedBox(height: 16),
                  const Text(
                    'Content',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6F1D1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contentController,
                    minLines: 6,
                    maxLines: 12,
                    decoration: InputDecoration(
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Existing Images',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (existingImages.isNotEmpty)
                        TextButton(
                          onPressed: _deleteAllImages,
                          child: const Text(
                            'Delete All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Preview of existing images with delete option
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: existingImages.map((imageUrl) {
                      return Stack(
                        children: [
                          Image.network(
                            imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _deleteExistingImage(imageUrl),
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

                  const Text(
                    'Add New Images',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Preview of new images picked by the user with option to remove before saving
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: newImages.map((file) {
                      return Stack(
                        children: [
                          Image.file(
                            file,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),

                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  newImages.remove(file);
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

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _pickImages,
                    child: const Text('Pick Images'),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: wineColor,
                      ),
                      onPressed: _saveChanges,
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
