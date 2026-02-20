Flutter Blog App

A simple 2D blog application built with Flutter and Supabase that supports authentication, blog creation, image upload, comments, and a clean UI.

⸻

Features
	•	Authentication: Login, Register using Supabase Auth
	•	CRUD Blogs: Create, read, update, delete blogs
	•	Image Upload: Add multiple images per blog or comment
	•	Comment Section: Users can comment and edit/delete their own comments
	•	Profile Management: Update username, profile picture
	•	Responsive UI: Drawer menu, grid layouts, 12-hour time format
	•	Pagination & Infinite Scroll: Blog list loads in pages
	•	Snackbars & Loading States: Feedback for operations

⸻

Getting Started

Prerequisites
	•	Flutter SDK >= 3.0
	•	Dart SDK (comes with Flutter)
	•	Android Studio or VS Code
	•	Supabase account and project

⸻

Setup
	1.	Clone the repo and navigate into the project directory.
	2.	Install dependencies using Flutter’s package manager.
	3.	Configure Supabase:

	•	Replace url and anonKey in lib/main.dart with your Supabase project credentials:  
          await Supabase.initialize(
          url: 'YOUR_SUPABASE_URL',
          anonKey: 'YOUR_SUPABASE_ANON_KEY',
        );
        
  4.	Run the app on your preferred device or emulator.

⸻

Folder Structure

lib/
 ├── main.dart           # App entry point & AuthGate
 ├── screens/            # All screens: Login, Register, MainPage, BlogView, EditBlog
 ├── widgets/            # Reusable widgets: CommentSection, Drawer
 ├── services/           # Supabase related functions (optional)
 └── models/             # Data models (optional)

 
⸻

Notes
	•	Blog and comment images are stored in Supabase Storage
	•	All state changes are handled via setState
	•	Async operations use Future, async/await and FutureBuilder
	•	Debug banner visible in debug mode; disable with:  MaterialApp(debugShowCheckedModeBanner: false)
