import 'package:flutter/material.dart';
import 'package:flutter_blog_app/screens/edit_blog_screen.dart';
import 'package:flutter_blog_app/screens/view_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'blog_view_screen.dart';

class BlogListScreen extends StatefulWidget {
  const BlogListScreen({super.key});

  @override
  State<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<BlogListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<
        ScaffoldState
      >(); // Key to control the Scaffold, used for opening the endDrawer programmatically.
  final supabase = Supabase.instance.client;

  // Delete a specific blog including its images in storage and blog_images table
  Future<void> _deleteBlog(Map<String, dynamic> blog) async {
    final String blogId = blog['id'];
    final List<dynamic> images = blog['images'] ?? [];

    // Show confirmation dialog before deleting the blog
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
    // If user did not confirm deletion, exit the function
    if (confirm != true) return;

    try {
      //  Delete images from storage bucket
      for (final imageUrl in images) {
        if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
          final uri = Uri.parse(imageUrl);
          final filePath = uri.pathSegments.last;
          await supabase.storage.from('blog-images').remove([
            filePath,
          ]); // Delete image from storage
        }
      }

      //  Delete image records from blog_images table
      await supabase.from('blog_images').delete().eq('blog_id', blogId);

      //  Delete comment images associated with this blog (both storage and table)
      final commentsResponse = await supabase
          .from('comments')
          .select('id')
          .eq('blog_id', blogId);

      //
      final commentIds = (commentsResponse as List)
          .map((c) => c['id'] as String)
          .toList();

      for (final commentId in commentIds) {
        // Fetch images for this comment
        final commentImages = await supabase
            .from('comment_images')
            .select('id, image_url')
            .eq('comment_id', commentId);

        for (final img in commentImages) {
          final imageUrl = img['image_url'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final uri = Uri.parse(imageUrl);
            final filePath = uri.pathSegments.last;
            // Delete image from storage
            await supabase.storage.from('comment-images').remove([filePath]);
          }
        }

        // Delete image records from comment_images table
        await supabase
            .from('comment_images')
            .delete()
            .eq('comment_id', commentId);
      }

      //  Delete all comments for this blog
      await supabase.from('comments').delete().eq('blog_id', blogId);

      //  Delete blog from blogs table
      await supabase.from('blogs').delete().eq('id', blogId);

      if (!mounted) return;

      // Refresh blog list after successful delete
      await fetchBlogs();

      // Show success snackbar before going back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blog deleted successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show success snackbar before going back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting blog: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // List of fetched blogs
  List<Map<String, dynamic>> blogs = [];

  // Loading indicator
  bool isLoading = true;

  // Pagination variables
  int currentPage = 0;
  final int pageSize = 5;
  int totalCount = 0;
  bool hasMore = true;

  // Define wine and peach colors for consistent theming
  final Color wineColor = const Color(0xFF6F1D1B);
  final Color peachColor = Color.fromARGB(255, 199, 133, 133);

  @override
  void initState() {
    super.initState();
    fetchBlogs();
  }

  /// Fetch blogs from Supabase with pagination
  Future<void> fetchBlogs() async {
    setState(() {
      isLoading = true; // Show loading indicator while fetching
      blogs = [];
    });

    try {
      // Get all blog IDs to calculate total count
      final allBlogs = await supabase.from('blogs').select('id');
      totalCount = (allBlogs as List).length;

      // Calculate range for current page
      final from = currentPage * pageSize;
      final to = from + pageSize - 1;

      // Fetch blogs for current page, ordered by newest first
      final response = await supabase
          .from('blogs')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      final fetchedBlogs = List<Map<String, dynamic>>.from(response as List);

      // Fetch profile pics and images for each blog author and blog
      List<Map<String, dynamic>> enrichedBlogs = [];
      for (final blog in fetchedBlogs) {
        // Fetch profile picture for blog author
        final profileResponse = await supabase
            .from('profiles')
            .select('profile_pic')
            .eq('id', blog['user_id'])
            .maybeSingle();
        // If profile exists, get profile_pic URL, otherwise it will be null
        final profilePic = profileResponse != null
            ? profileResponse['profile_pic']
            : null;

        // Fetch images for the blog from blog_images table
        // This gets a list of image URLs associated with the blog
        final imagesResponse = await supabase
            .from('blog_images')
            .select('image_url')
            .eq('blog_id', blog['id']);

        final List<String> blogImages = [];
        for (final img in imagesResponse) {
          if (img['image_url'] != null) {
            blogImages.add(img['image_url'] as String);
          }
        }

        // Add profile_pic and images to blog map
        final enrichedBlog = Map<String, dynamic>.from(blog);
        enrichedBlog['profile_pic'] = profilePic;
        enrichedBlog['images'] = blogImages;
        enrichedBlogs.add(enrichedBlog);
      }

      setState(() {
        blogs = enrichedBlogs;
        hasMore = (from + pageSize) < totalCount;
      });
    } catch (e) {
      // Show error snackbar if fetching blogs fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching blogs: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

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

    if (shouldLogout == true) {
      Navigator.pop(context); // Close drawer if open
      // pushReplacementNamed replaces the current route (authenticated area)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false, // remove all previous routes
      );
    }
  }

  /// Helper method to view image fullscreen with pinch-to-zoom
  void _viewImageFullscreen(String imageUrl) {
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

  /// Build a single blog item
  Widget buildBlogItem(Map<String, dynamic> blog) {
    final images = blog['images'] as List? ?? [];
    final imageCount = images.length;
    final String? blogOwnerId = blog['user_id'];
    final String? currentUserId = supabase.auth.currentUser?.id;

    // Format publish date from created_at
    String formattedDate = '';
    if (blog['created_at'] != null) {
      final DateTime parsedDate = DateTime.parse(blog['created_at']).toLocal();

      final int hour = parsedDate.hour;
      final int hour12 = hour == 0
          ? 12
          : hour > 12
          ? hour - 12
          : hour;

      final String period = hour >= 12 ? 'PM' : 'AM';

      formattedDate =
          '${parsedDate.month.toString().padLeft(2, '0')}/'
          '${parsedDate.day.toString().padLeft(2, '0')}/'
          '${parsedDate.year} '
          '${hour12.toString().padLeft(2, '0')}:'
          '${parsedDate.minute.toString().padLeft(2, '0')} $period';
    }
    // Builds the image grid for a blog post based on the number of images, following Twitter-style layouts for reference.
    Widget buildImageGrid() {
      if (imageCount == 0)
        return const SizedBox.shrink(); // If there are no images, return an empty widget.

      // Determine grid layout based on image count
      if (imageCount == 1) {
        // Single image full width, tap to open fullscreen
        return GestureDetector(
          onTap: () => _viewImageFullscreen(images[0]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images[0],
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      } else if (imageCount == 3) {
        // Twitter-style 3 images layout reference
        return SizedBox(
          height: 200,
          child: Row(
            children: [
              // First column - 1 large image
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewImageFullscreen(images[0]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[0],
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Second column - 2 images stacked (column of 2)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _viewImageFullscreen(images[1]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[1],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _viewImageFullscreen(images[2]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[2],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        // For 2 or more images, use GridView with 2 columns
        // For 4 images: 2x2 grid
        // For 5+ images: show first 3 images in grid, 4th grid image blurred with +N overlay
        // Only the blurred overlay image with +N triggers navigation to BlogViewScreen.
        // All other images open fullscreen with pinch-to-zoom.
        int gridImageCount = imageCount >= 5 ? 4 : imageCount;

        return SizedBox(
          height:
              (MediaQuery.of(context).size.width - 62 - 12) /
                  2 *
                  ((gridImageCount + 1) ~/ 2) +
              (gridImageCount > 2 ? 4 : 0),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: gridImageCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              // If 5+ images and this is the 4th image (index 3), show blurred overlay with +N
              if (imageCount >= 5 && index == 3) {
                final remainingCount = imageCount - 3;
                return GestureDetector(
                  // Only the +N blurred overlay image navigates to BlogViewScreen
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlogViewScreen(blog: blog),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          images[3],
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.6),
                          colorBlendMode: BlendMode.darken,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$remainingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Normal image grid item
                return GestureDetector(
                  // Tap opens image fullscreen (pinch-to-zoom)
                  onTap: () => _viewImageFullscreen(images[index]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        );
      }
    }

    return GestureDetector(
      // Tapping anywhere on the blog card (except images) opens the BlogViewScreen to view full content and comments.
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => BlogViewScreen(blog: blog)),
        );

        // If BlogViewScreen returns true (meaning blog was deleted),
        // refresh the blog list
        if (result == true) {
          fetchBlogs();
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: const Color.fromARGB(255, 235, 213, 220),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row with profile picture, username/title, and kebab menu
              Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: wineColor,
                        backgroundImage: blog['profile_pic'] != null
                            ? NetworkImage(blog['profile_pic'])
                            : null,
                        child: blog['profile_pic'] == null
                            ? const Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // Username + date + title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blog['username'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: wineColor,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Publish date
                            if (formattedDate.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),

                            Text(
                              blog['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Kebab menu/more_vert positioned top-right (only if current user owns blog)
                  if (currentUserId != null && currentUserId == blogOwnerId)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditBlogScreen(blog: blog),
                              ),
                            );
                            // If EditBlogScreen returns true (meaning blog was updated),
                            // refresh the blog list
                            if (result == true) {
                              await fetchBlogs();
                            }
                          } else if (value == 'delete') {
                            // Delete blog and refresh list on success
                            await _deleteBlog(blog);
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
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(
                  left: 62,
                ), // Indent content to align with text, not profile pic
                child: Text(
                  blog['content'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              // Display blog images in Twitter-style grid layout
              if (imageCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 62, top: 12),
                  child: buildImageGrid(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(
          context,
          true,
        ); // return true to trigger refresh on main page
        return false; // prevent default pop
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text('Blogs', style: TextStyle(color: Colors.white)),
          backgroundColor: wineColor,
          actions: [
            IconButton(
              icon: Icon(Icons.menu, color: peachColor),
              onPressed: () {
                // Open the endDrawer programmatically when the menu icon is tapped.
                _scaffoldKey.currentState?.openEndDrawer();
              },
              tooltip: 'Open menu',
            ),
          ],
        ),
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
                      fetchBlogs(); // Refresh blog list if needed
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

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : blogs.isEmpty
            ? const Center(child: Text('No blogs found'))
            : Column(
                children: [
                  // Blog list
                  Expanded(
                    child: ListView.builder(
                      itemCount: blogs.length,
                      itemBuilder: (context, index) {
                        final blog = blogs[index];
                        return buildBlogItem(blog);
                      },
                    ),
                  ),
                  // Pagination buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed:
                              currentPage >
                                  0 // Only enable "Prev" if not on the first page
                              ? () {
                                  setState(() {
                                    currentPage--;
                                  });
                                  fetchBlogs();
                                }
                              : null,
                          child: const Text(
                            'Prev',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: wineColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        Text('Page ${currentPage + 1}'),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: hasMore
                              ? () {
                                  setState(() {
                                    currentPage++; // Increment page number to fetch next set of blogs
                                  });
                                  fetchBlogs();
                                }
                              : null,
                          child: const Text(
                            'Next',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: wineColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
