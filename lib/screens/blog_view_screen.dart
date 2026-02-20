import 'package:flutter/material.dart';
import 'package:flutter_blog_app/screens/edit_blog_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blog_app/widgets/comment_section.dart';

/// BlogViewScreen displays the details of a single blog post.
/// Expects a [blog] Map with keys: username, profile_pic, title, content, images (list).
class BlogViewScreen extends StatefulWidget {
  final Map<String, dynamic> blog;
  const BlogViewScreen({
    super.key,
    required this.blog,
  }); // Blog data passed from previous screen

  @override
  State<BlogViewScreen> createState() => _BlogViewScreenState();
}

class _BlogViewScreenState extends State<BlogViewScreen> {
  final supabase = Supabase.instance.client;

  // Delete blog and all associated images and comments
  Future<void> _deleteBlog() async {
    final blog = widget.blog;
    final String blogId = blog['id'];
    final List<dynamic> images = blog['images'] ?? [];

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Blog'),
        content: const Text(
          'Are you sure you want to delete this blog? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User cancelled deletion

    try {
      // Delete images from storage
      for (final imageUrl in images) {
        if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
          final uri = Uri.parse(imageUrl);
          final filePath = uri.pathSegments.last;
          await supabase.storage.from('blog-images').remove([
            filePath,
          ]); // remove by file path in storage
        }
      }

      // Delete image records from blog_images table
      await supabase.from('blog_images').delete().eq('blog_id', blogId);

      // Delete ALL comment images (storage + table)
      final commentsResponse = await supabase
          .from('comments')
          .select('id')
          .eq('blog_id', blogId);

      final commentIds = (commentsResponse as List)
          .map((c) => c['id'] as String)
          .toList();

      for (final commentId in commentIds) {
        final commentImages = await supabase
            .from('comment_images')
            .select('id, image_url')
            .eq('comment_id', commentId);

        for (final img in commentImages) {
          final imageUrl = img['image_url'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final uri = Uri.parse(imageUrl);
            final filePath = uri.pathSegments.last;
            await supabase.storage.from('comment-images').remove([filePath]);
          }
        }

        await supabase
            .from('comment_images')
            .delete()
            .eq('comment_id', commentId);
      }

      //  Delete all comments
      await supabase.from('comments').delete().eq('blog_id', blogId);

      //  Delete blog from blogs table
      await supabase.from('blogs').delete().eq('id', blogId);

      if (!mounted) return;

      Navigator.of(context).pop(true); // return true to trigger refresh

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blog deleted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting blog: $e')));
    }
  }

  // Show image in fullscreen with zoom when tapped
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

  @override
  Widget build(BuildContext context) {
    // Extract blog fields
    final blog = widget.blog;
    final String username = blog['username'] ?? 'Unknown';
    final String profilePic = blog['profile_pic'] ?? '';
    final String title = blog['title'] ?? '';
    final String content = blog['content'] ?? '';
    final List<dynamic> images = blog['images'] ?? [];

    // Format publish date (12-hour format with AM/PM)
    String formattedDate = '';
    if (blog['created_at'] != null) {
      final DateTime parsedDate = DateTime.parse(blog['created_at']).toLocal();

      // Convert to 12-hour format with AM/PM
      final int hour = parsedDate.hour;
      final int hour12 = hour == 0
          ? 12
          : hour > 12
          ? hour - 12
          : hour;
      final String period = hour >= 12 ? 'PM' : 'AM';
      // Final formatted date string
      formattedDate =
          '${parsedDate.month.toString().padLeft(2, '0')}/'
          '${parsedDate.day.toString().padLeft(2, '0')}/'
          '${parsedDate.year} '
          '${hour12.toString().padLeft(2, '0')}:'
          '${parsedDate.minute.toString().padLeft(2, '0')} $period';
    }

    // Check if current user is the blog owner to conditionally show edit/delete options
    final String? blogOwnerId = blog['user_id'];
    final String? currentUserId = supabase.auth.currentUser?.id;

    // Wine theme colors
    const Color wineColor = Color(0xFF6F1D1B);
    const Color wineLight = Color(0xFFF8E5EC);
    const Color wineAccent = Color(0xFFB67B8F);

    return Scaffold(
      backgroundColor: wineLight,
      appBar: AppBar(
        backgroundColor: wineColor,
        title: const Text(
          'Blog Details',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: profile picture and username
            Row(
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 28,
                  backgroundColor: wineColor,
                  backgroundImage: profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : null,
                  child: profilePic.isEmpty
                      ? const Icon(Icons.person, size: 32, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),

                // Username + Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: wineColor,
                        ),
                      ),
                      if (formattedDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Kebab menu/more_vert (only visible if current user is the blog owner)
                if (currentUserId != null && currentUserId == blogOwnerId)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: wineColor),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditBlogScreen(blog: blog),
                          ),
                        );
                      } else if (value == 'delete') {
                        _deleteBlog();
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
            const SizedBox(height: 12),
            // Divider between username and blog title
            Container(
              height: 1,
              color: wineColor.withOpacity(0.5),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
            // Blog title
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: wineColor,
              ),
            ),
            const SizedBox(height: 16),
            // Blog content
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF3E2431),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Blog images (if any)
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 10), // Spacing between images
                  itemBuilder: (context, i) {
                    final String url = images[i] ?? '';
                    return GestureDetector(
                      onTap: () => _showImageFullscreen(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: wineAccent.withOpacity(0.13),
                          width: 160,
                          height: 160,
                          child: url.isNotEmpty
                              ? Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                  (progress
                                                          .expectedTotalBytes ??
                                                      1)
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(
                                        Icons.broken_image,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                )
                              : const Icon(
                                  Icons.broken_image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
            CommentSection(blogId: blog['id']), // Comment section for the blog
          ],
        ),
      ),
    );
  }
}
