
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/school_context.dart';
import 'services/background_cache_service.dart';
import 'announcements_page.dart';
import 'admin_home_page.dart';
import 'admin_add_user_page.dart';
import 'admin_post_page.dart';
import 'notification_service.dart';
import 'navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_downloader/background_downloader.dart';
import 'admin_users_page.dart';
import 'admin_user_details_page.dart';
import 'admin_manage_classes_page.dart';
import 'admin_manage_subjects_page.dart';
import 'admin_cleanup_page.dart';
import 'cleanup_status_page.dart';
import 'group_create_page.dart';
import 'group_chat_page.dart';
import 'auth_choice_page.dart';
import 'admin_approvals_page.dart';
import 'force_password_change_page.dart';
import 'downloads_page.dart';
import 'multi_r2_media_uploader_page.dart';
import 'students_page.dart';
import 'staff_page.dart';
import 'services/route_persistence_service.dart';
import 'school_key_entry_page.dart';
import 'school_registration_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler uses dynamic Firebase options
  await Firebase.initializeApp(options: await DynamicFirebaseOptions.getOptions());
}

@pragma('vm:entry-point')
void backgroundTaskDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background task uses dynamic Firebase options
  await Firebase.initializeApp(options: await DynamicFirebaseOptions.getOptions());
  Workmanager().executeTask((task, inputData) async {
    try {
      // inputData may contain preset and targets
      final preset = inputData?["preset"] as String?; // today|last7|last30
      final includeChats = (inputData?["includeChats"] as bool?) ?? true;
      final includeAnnouncements = (inputData?["includeAnnouncements"] as bool?) ?? true;
      final includeDeviceCache = (inputData?["includeDeviceCache"] as bool?) ?? false;
      final includeR2Storage = false; // ALWAYS FALSE - disable auto R2 cleanup
      
      // Check daily cleanup status for shared cleanup
      final hasSharedCleanup = includeChats || includeAnnouncements || includeR2Storage;
      if (hasSharedCleanup) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final statusDoc = FirebaseFirestore.instance.collection('app_config').doc('daily_cleanup_status');
        
        bool canProceed = false;
        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final doc = await transaction.get(statusDoc);
            final data = doc.data();
            
            if (data != null && data['completedDate'] == today && data['preset'] == preset) {
              // Already completed today
              canProceed = false;
              return;
            }
            
            // Mark as completed by background task
            transaction.set(statusDoc, {
              'completedDate': today,
              'completedBy': 'background_task',
              'preset': preset ?? 'today',
              'timestamp': FieldValue.serverTimestamp(),
              'deviceInfo': 'Background Task',
            });
            canProceed = true;
          });
        } catch (e) {
          print("Background task: Daily cleanup already completed or error: $e");
          canProceed = false;
        }
        
        if (!canProceed) {
          print("Background task: Skipping cleanup - already completed today");
          return true; // Task completed successfully (by skipping)
        }
      }
      
      DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
      DateTime _endExclusiveOfDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
      DateTime now = DateTime.now();
      DateTime start;
      DateTime endEx;
      switch (preset) {
        case 'last7':
          start = _startOfDay(now.subtract(const Duration(days: 6)));
          endEx = _endExclusiveOfDay(now);
          break;
        case 'last30':
          start = _startOfDay(now.subtract(const Duration(days: 29)));
          endEx = _endExclusiveOfDay(now);
          break;
        case 'today':
        default:
          start = _startOfDay(now);
          endEx = _endExclusiveOfDay(now);
      }

      Future<int> _deleteRange(String collection, DateTime s, DateTime e) async {
        int deleted = 0;
        final base = FirebaseFirestore.instance
            .collection(collection)
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(s))
            .where('timestamp', isLessThan: Timestamp.fromDate(e))
            .orderBy('timestamp');
        DocumentSnapshot? cursor;
        while (true) {
          Query q = base.limit(300);
          if (cursor != null) q = (q as Query<Map<String, dynamic>>).startAfterDocument(cursor) as Query;
          final snap = await q.get();
          if (snap.docs.isEmpty) break;
          final batch = FirebaseFirestore.instance.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          deleted += snap.docs.length;
          cursor = snap.docs.last;
          await Future<void>.delayed(Duration.zero);
        }
        return deleted;
      }

      if (includeChats) {
        await _deleteRange('chats', start, endEx);
      }
      if (includeAnnouncements) {
        await _deleteRange('communications', start, endEx);
      }
      
      // Handle device cache deletion
      if (includeDeviceCache) {
        try {
          final prefs = await SharedPreferences.getInstance();
          
          // Clear SharedPreferences cache entries
          await prefs.setString('downloaded_files', '{}');
          await prefs.setString('downloaded_thumbnails', '{}');
          
          // Clear actual device cache directories
          int filesDeleted = 0;
          
          // Clear temporary cache directory
          try {
            final cacheDir = await getTemporaryDirectory();
            print("Background: Clearing cache directory: ${cacheDir.path}");
            
            if (await cacheDir.exists()) {
              final entities = cacheDir.listSync(recursive: true);
              for (final entity in entities) {
                try {
                  if (entity is File) {
                    await entity.delete();
                    filesDeleted++;
                  }
                } catch (e) {
                  print("Background: Error deleting file: ${entity.path} - $e");
                }
              }
            }
          } catch (e) {
            print("Background: Error accessing cache directory: $e");
          }
          
          // Clear downloads directory
          try {
            final downloadDir = await getApplicationDocumentsDirectory();
            final downloadPath = Directory('${downloadDir.path}/downloads');
            print("Background: Clearing downloads directory: ${downloadPath.path}");
            
            if (await downloadPath.exists()) {
              final entities = downloadPath.listSync(recursive: true);
              for (final entity in entities) {
                try {
                  if (entity is File) {
                    await entity.delete();
                    filesDeleted++;
                  }
                } catch (e) {
                  print("Background: Error deleting download: ${entity.path} - $e");
                }
              }
            }
          } catch (e) {
            print("Background: Error accessing downloads directory: $e");
          }
          
          print("Background: Deleted $filesDeleted device cache files");
        } catch (e) {
          print("Background task: Error clearing device cache: $e");
        }
      }
      
      // Handle R2 storage deletion
      if (includeR2Storage) {
        try {
          // Since we can't use Minio directly in background task,
          // we'll mark a flag in Firestore that will trigger deletion on next app launch
          
          // Store the cleanup request in Firestore
          await FirebaseFirestore.instance.collection('app_config').doc('pending_r2_cleanup').set({
            'enabled': true,
            'createdAt': FieldValue.serverTimestamp(),
            'preset': preset ?? 'today',
            'note': 'Background task requested FULL R2 bucket cleanup',
            'deleteAll': true  // Flag to indicate all files should be deleted
          });
          
          print("Scheduled full R2 bucket cleanup for next app launch");
        } catch (e) {
          print("Background task: Error scheduling R2 cleanup: $e");
        }
      }
    } catch (e) {
      print("Background task error: $e");
    }
    return Future.value(true);
  });
}

void main() async {
  final startupStopwatch = Stopwatch()..start();
  print('🚀 APP STARTUP STARTED at ${DateTime.now().toIso8601String()}');
  
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ WidgetsFlutterBinding initialized - ${startupStopwatch.elapsedMilliseconds}ms');
  
  // 🚀 Initialize Firebase with FAST startup (no network delays!)
  // Uses cached config or defaults immediately, updates config in background
  final firebaseStopwatch = Stopwatch()..start();
  await Firebase.initializeApp(
    options: await DynamicFirebaseOptions.getOptionsForStartup(),
  );
  print('🔥 Firebase initialized - ${firebaseStopwatch.elapsedMilliseconds}ms (Total: ${startupStopwatch.elapsedMilliseconds}ms)');
  
  // 🔥 Initialize SchoolContext - provides schoolId throughout the app
  final schoolContextStopwatch = Stopwatch()..start();
  await SchoolContext.initialize();
  print('🏫 SchoolContext initialized - ${schoolContextStopwatch.elapsedMilliseconds}ms (Total: ${startupStopwatch.elapsedMilliseconds}ms)');
  
  // Register background handler for FCM (lightweight - just handler registration)
  final fcmStopwatch = Stopwatch()..start();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('📱 FCM background handler registered - ${fcmStopwatch.elapsedMilliseconds}ms (Total: ${startupStopwatch.elapsedMilliseconds}ms)');
  
  // 🚀 DEFERRED: Heavy services will initialize after UI is shown
  // - Workmanager initialization (mobile cleanup tasks)
  // - Desktop cleanup timer 
  // - Detailed notification setup
  // - Background image precaching
  // - First admin user check
  // - Firebase config background update
  
  print('🎯 Starting UI - Total startup time: ${startupStopwatch.elapsedMilliseconds}ms');
  runApp(const MyApp());
  print('🎉 runApp() completed - Total startup time: ${startupStopwatch.elapsedMilliseconds}ms');
}

/// Initialize Workmanager in the background (deferred from startup)
/// This can be called after the UI is ready to avoid startup delays
Future<void> initializeWorkmanagerInBackground() async {
  try {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                    defaultTargetPlatform == TargetPlatform.iOS)) {
      await Workmanager().initialize(backgroundTaskDispatcher, isInDebugMode: false);
      debugPrint('📱 Workmanager initialized in background');
    }
  } catch (e) {
    debugPrint('⚠️ Error initializing Workmanager in background: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Communication',
      navigatorKey: rootNavigatorKey,
      initialRoute: '/schoolKeyCheck',
      onGenerateRoute: (settings) {
        if (settings.name == '/schoolKeyCheck') {
          return MaterialPageRoute(builder: (_) => const SchoolKeyCheckScreen());
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const _SessionGate());
        }
        if (settings.name == '/admin') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          final role = args?['role'] ?? 'admin';
          return MaterialPageRoute(builder: (_) => AdminHomePage(currentUserId: userId, currentUserRole: role));
        }
        if (settings.name == '/forcePassword') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] as String? ?? '';
          return MaterialPageRoute(builder: (_) => ForcePasswordChangePage(userId: userId));
        }
        if (settings.name == '/groups/new') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? '';
          return MaterialPageRoute(builder: (_) => GroupCreatePage(currentUserId: userId));
        }
        if (settings.name == '/groups/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          final groupId = args?['groupId'] as String? ?? '';
          final name = args?['name'] as String? ?? 'Group';
          final userId = args?['userId'] as String? ?? '';
          return MaterialPageRoute(builder: (_) => GroupChatPage(groupId: groupId, groupName: name, currentUserId: userId));
        }
        if (settings.name == '/admin/addUser') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminAddUserPage(currentUserId: userId));
        }
        if (settings.name == '/admin/approvals') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminApprovalsPage(currentUserId: userId));
        }
        if (settings.name == '/admin/post') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminPostPage(currentUserId: userId));
        }
        if (settings.name == '/admin/users') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminUsersPage(currentUserId: userId));
        }
        if (settings.name == '/admin/manageClasses') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminManageClassesPage(currentUserId: userId));
        }
        if (settings.name == '/admin/manageSubjects') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminManageSubjectsPage(currentUserId: userId));
        }
        if (settings.name == '/admin/cleanup') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? 'firstadmin';
          return MaterialPageRoute(builder: (_) => AdminCleanupPage(currentUserId: userId));
        }
        if (settings.name == '/cleanup/status') {
          return MaterialPageRoute(builder: (_) => const CleanupStatusPage());
        }
        if (settings.name == '/admin/users/details') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userRefPath = args?['userRefPath'] as String?;
          if (userRefPath == null || userRefPath.isEmpty) {
            return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('No user selected'))));
          }
          return MaterialPageRoute(builder: (_) => AdminUserDetailsPage(userRefPath: userRefPath));
        }
        if (settings.name == '/announcements') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? '';
          final role = args?['role'] ?? 'user';
          return MaterialPageRoute(builder: (_) => AnnouncementsPage(currentUserId: userId, currentUserRole: role));
        }
        if (settings.name == '/downloads') {
          return MaterialPageRoute(builder: (_) => const DownloadsPage());
        }
        if (settings.name == '/upload/media') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? '';
          final role = args?['role'] ?? 'user';
          return MaterialPageRoute(builder: (_) => MultiR2MediaUploaderPage(currentUserId: userId, currentUserRole: role));
        }
        if (settings.name == '/students') {
          return MaterialPageRoute(builder: (_) => const StudentsPage());
        }
        if (settings.name == '/staff') {
          return MaterialPageRoute(builder: (_) => const StaffPage());
        }
        return null;
      },
    );
  }
}

// AuthGate removed for simple userId/password flow

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  
  @override
  void initState() {
    super.initState();
    _loadBackgroundAndDecide();
  }

  Future<void> _loadBackgroundAndDecide() async {
    final sessionStopwatch = Stopwatch()..start();
    print('🔍 SessionGate: Starting FAST session check at ${DateTime.now().toIso8601String()}');
    
    // 🚀 ONLY check session data - everything else happens in background!
    final sessionCheckStopwatch = Stopwatch()..start();
    final userId = await DynamicFirebaseOptions.getSessionUserId();
    final role = await DynamicFirebaseOptions.getSessionRole();
    print('👤 SessionGate: Session check completed - ${sessionCheckStopwatch.elapsedMilliseconds}ms');
    
    // Mark that app has been launched (only for first-time check)
    final prefs = await SharedPreferences.getInstance();
    final hasLaunchedBefore = prefs.getBool('has_launched_before') ?? false;
    if (!hasLaunchedBefore) {
      await prefs.setBool('has_launched_before', true);
    }
    
    // If session_* keys exist, keep user signed in across restarts until they explicitly sign out
    if (!mounted) return;
    
    if (userId != null && userId.isNotEmpty) {
      print('✅ SessionGate: User session found, navigating to admin page - Total SessionGate time: ${sessionStopwatch.elapsedMilliseconds}ms');
      
      // All users land on Current Page (admin and non-admin). Admin-only actions are hidden for non-admins.
      // ALL heavy operations (notifications, background images, cache) happen AFTER UI loads!
      Navigator.pushReplacementNamed(context, '/admin', arguments: {'userId': userId, 'role': role ?? 'user'});
    } else {
      print('🔐 SessionGate: No session found, navigating to auth - Total SessionGate time: ${sessionStopwatch.elapsedMilliseconds}ms');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthChoicePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

class NameFormPage extends StatefulWidget {
  const NameFormPage({super.key});

  @override
  State<NameFormPage> createState() => _NameFormPageState();
}

class _NameFormPageState extends State<NameFormPage> {
  final TextEditingController _nameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _addNameToFirestore() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('names').add({
        'name': _nameController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name added successfully!')),
      );

      _nameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AdilabadAutoCabs')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _addNameToFirestore,
              child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Text('Add to Firebase'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('names')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Text('No names added yet.');
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unknown';
                      
                      return Card(
                        child: ListTile(
                          title: Text(name),
                          subtitle: data['timestamp'] != null 
                              ? Text('Added: ${(data['timestamp'] as Timestamp).toDate()}')
                              : const Text('Just added'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Desktop cleanup timer for testing (only works while app is running)
Timer? _desktopCleanupTimer;

void _startDesktopCleanupTimer() {
  // Check every minute for scheduled cleanup time
  _desktopCleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('cleanup_recurring_enabled') ?? false;
      
      if (!enabled) return;
      
      final hour = prefs.getInt('cleanup_recurring_hour') ?? 6;
      final minute = prefs.getInt('cleanup_recurring_minute') ?? 0;
      final now = DateTime.now();
      
      // Check if it's the scheduled time (within 1 minute window)
      if (now.hour == hour && now.minute == minute) {
        print("Desktop cleanup timer triggered at ${now.hour}:${now.minute}");
        
        // Execute the cleanup similar to the background task
        final preset = prefs.getString('cleanup_recurring_preset') ?? 'today';
        final includeChats = prefs.getBool('cleanup_recurring_includeChats') ?? true;
        final includeAnnouncements = prefs.getBool('cleanup_recurring_includeAnnouncements') ?? true;
        final includeDeviceCache = prefs.getBool('cleanup_recurring_includeDeviceCache') ?? false;
        
        await _performDesktopCleanup(preset, includeChats, includeAnnouncements, includeDeviceCache);
      }
    } catch (e) {
      print("Desktop cleanup timer error: $e");
    }
  });
}

Future<void> _performDesktopCleanup(String preset, bool includeChats, bool includeAnnouncements, bool includeDeviceCache) async {
  try {
    final hasSharedCleanup = includeChats || includeAnnouncements;
    if (hasSharedCleanup) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final statusDoc = FirebaseFirestore.instance.collection('app_config').doc('daily_cleanup_status');
      
      bool canProceed = false;
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final doc = await transaction.get(statusDoc);
          final data = doc.data();
          
          if (data != null && data['completedDate'] == today && data['preset'] == preset) {
            canProceed = false;
            return;
          }
          
          transaction.set(statusDoc, {
            'completedDate': today,
            'completedBy': 'desktop_timer',
            'preset': preset,
            'timestamp': FieldValue.serverTimestamp(),
            'deviceInfo': 'Desktop Timer',
          });
          canProceed = true;
        });
        
        if (canProceed) {
          print("Desktop cleanup executed for preset: $preset");
          // Here you would implement the actual cleanup logic
          // For now, just log that it would happen
        } else {
          print("Desktop cleanup skipped - already completed today");
        }
      } catch (e) {
        print("Desktop cleanup transaction error: $e");
      }
    }
  } catch (e) {
    print("Desktop cleanup error: $e");
  }
}

// School Key Check Screen - Shows on first launch
class SchoolKeyCheckScreen extends StatefulWidget {
  const SchoolKeyCheckScreen({Key? key}) : super(key: key);

  @override
  State<SchoolKeyCheckScreen> createState() => _SchoolKeyCheckScreenState();
}

class _SchoolKeyCheckScreenState extends State<SchoolKeyCheckScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSchoolKey();
  }

  Future<void> _checkSchoolKey() async {
    try {
      final hasKey = await DynamicFirebaseOptions.hasSchoolKey();
      
      if (hasKey) {
        // Key exists, proceed to login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // No key, show key entry page
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SchoolKeyEntryPage(),
              fullscreenDialog: true,
            ),
          );
          
          if (result == true) {
            // Key configured successfully, proceed to login
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          } else {
            // User cancelled, show again
            setState(() => _isChecking = true);
            _checkSchoolKey();
          }
        }
      }
    } catch (e) {
      // On error, proceed to login anyway (fallback)
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Initializing...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
