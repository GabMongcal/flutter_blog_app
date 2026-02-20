import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentSection extends StatefulWidget {
  final String blogId;

  const CommentSection({super.key, required this.blogId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> comments = [];
  List<XFile> selectedImages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  // FETCH COMMENTS WITH IMAGES
  Future<void> fetchComments() async {
    final data = await supabase
        .from('comments')
        .select('*, comment_images(*)')
        .eq('blog_id', widget.blogId)
        .order('created_at', ascending: true);

    setState(() {
      comments = List<Map<String, dynamic>>.from(data);
    });
  }

  // PICK MULTIPLE IMAGES
  Future<void> pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        selectedImages = images;
      });
    }
  }

  // ADD COMMENT WITH OPTIONAL IMAGES
  Future<void> addComment() async {
    final user = supabase.auth.currentUser;
    if (user == null || _commentController.text.trim().isEmpty)
      return; // Basic validation: ensure user is logged in and comment is not empty

    setState(() => isLoading = true);

    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    // Insert comment first
    final inserted = await supabase
        .from('comments')
        .insert({
          'blog_id': widget.blogId,
          'user_id': user.id,
          'username': profile['username'],
          'profile_pic': profile['profile_pic'],
          'content': _commentController.text.trim(),
        })
        .select() // Get the inserted comment with its generated ID to associate images
        .single();

    final commentId = inserted['id'];

    // Upload images if any
    for (var image in selectedImages) {
      final file = File(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await supabase.storage.from('comment-images').upload(fileName, file);

      final imageUrl = supabase.storage
          .from('comment-images')
          .getPublicUrl(fileName);

      await supabase.from('comment_images').insert({
        'comment_id': commentId,
        'image_url': imageUrl,
      });
    }

    _commentController.clear();
    selectedImages.clear();
    await fetchComments();

    setState(() => isLoading = false);
  }

  // Helper to open image in fullscreen dialog
  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: InteractiveViewer(
              maxScale: 5.0,
              minScale: 1.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> deleteComment(String commentId) async {
    //  Fetch all images for this comment
    final imagesData = await supabase
        .from('comment_images')
        .select()
        .eq('comment_id', commentId);

    // Delete each file from storage
    for (final img in imagesData) {
      final imageUrl = img['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final uri = Uri.parse(imageUrl);
        final fileName = uri.pathSegments.last;
        await supabase.storage.from('comment-images').remove([fileName]);
      }
    }

    //  Delete records from comment_images table
    await supabase.from('comment_images').delete().eq('comment_id', commentId);

    //  Delete the comment itself
    await supabase.from('comments').delete().eq('id', commentId);

    //  Refresh local comments list
    await fetchComments();
  }

  Future<void> editCommentWithImages(Map<String, dynamic> comment) async {
    final TextEditingController editController = TextEditingController(
      text: comment['content'],
    );
    List<dynamic> existingImages = List.from(comment['comment_images'] ?? []);
    List<dynamic> imagesMarkedForDeletion = [];
    List<XFile> newImages = [];
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Comment'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isLoading)
                      const Center(child: CircularProgressIndicator()),
                    TextField(
                      controller: editController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Edit your comment',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (existingImages.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: existingImages.map<Widget>((img) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img['image_url'],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      imagesMarkedForDeletion.add(
                                        img,
                                      ); // Mark image for deletion but keep in existingImages for now to avoid UI flicker until confirmed
                                      existingImages.remove(
                                        img,
                                      ); // Mark image for deletion and remove from UI immediately
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 12),

                    // NEW IMAGES PREVIEW
                    if (newImages.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: newImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final img = entry.value;

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(img.path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Remove (X) Button for new images
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      newImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 12),
                    // Button to pick new images to add
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await _picker.pickMultiImage();
                        if (picked.isNotEmpty) {
                          setDialogState(() {
                            newImages.addAll(picked);
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Add Images'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      // Update text
                      await supabase
                          .from('comments')
                          .update({'content': editController.text.trim()})
                          .eq('id', comment['id']);

                      // Delete removed images (only now)
                      for (var img in imagesMarkedForDeletion) {
                        final imageUrl = img['image_url'] as String?;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          // Extract file name from URL
                          final uri = Uri.parse(imageUrl);
                          final fileName = uri.pathSegments.last;

                          // Delete from Supabase Storage
                          await supabase.storage.from('comment-images').remove([
                            fileName,
                          ]);
                        }

                        // Delete from comment_images table
                        await supabase
                            .from('comment_images')
                            .delete()
                            .eq('id', img['id']);
                      }

                      // Upload newly added images
                      for (var image in newImages) {
                        final file = File(image.path);
                        final fileName =
                            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

                        await supabase.storage
                            .from('comment-images')
                            .upload(fileName, file);

                        final imageUrl = supabase.storage
                            .from('comment-images')
                            .getPublicUrl(fileName);

                        await supabase.from('comment_images').insert({
                          'comment_id': comment['id'],
                          'image_url': imageUrl,
                        });
                      }

                      Navigator.pop(context);
                      await fetchComments();

                      // Show success snackbar
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comment edited successfully!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to edit comment: $e')),
                        );
                      }
                    } finally {
                      setDialogState(() {
                        isLoading = false;
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatCommentDate(String date) {
    final parsed = DateTime.parse(date).toLocal();

    final hour = parsed.hour > 12
        ? parsed.hour - 12
        : parsed.hour == 0
        ? 12
        : parsed.hour;

    final period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    // Wine color palette consistent with Login and Edit Profile screens.
    const wineColor = Color(0xFF6F1D1B);
    const wineAccent = Color(0xFFB67B8F);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(), // Visual separation from blog content
        const SizedBox(height: 8),
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: wineColor,
          ),
        ),
        const SizedBox(height: 12),

        // COMMENT LIST
        ...comments.map((comment) {
          final currentUserId = supabase.auth.currentUser?.id;
          final images = comment['comment_images'] as List<dynamic>? ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: wineAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          comment['profile_pic'] != null &&
                              comment['profile_pic'].toString().isNotEmpty
                          ? NetworkImage(comment['profile_pic'])
                          : null,
                      child:
                          comment['profile_pic'] == null ||
                              comment['profile_pic'].toString().isEmpty
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['username'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            comment['created_at'] != null
                                ? _formatCommentDate(comment['created_at'])
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentUserId == comment['user_id'])
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            editCommentWithImages(comment);
                          } else if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Comment'),
                                content: const Text(
                                  'Are you sure you want to delete this comment? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await deleteComment(comment['id']);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Comment deleted successfully.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(comment['content'] ?? ''),

                // DISPLAY IMAGES IF ANY
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: images.map((img) {
                      final imageUrl = img['image_url'] as String;
                      return GestureDetector(
                        onTap: () => _showImageFullscreen(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 16),

        if (selectedImages
            .isNotEmpty) // Preview of newly selected images before posting comment
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final img = entry.value;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(img.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Remove (X) Button
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

        const SizedBox(height: 8),

        // INPUT AREA
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image, color: wineColor),
              onPressed: pickImages,
            ),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? const CircularProgressIndicator()
                : IconButton(
                    icon: const Icon(Icons.send, color: wineColor),
                    onPressed: addComment,
                  ),
          ],
        ),
      ],
    );
  }
}
