import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'navigation_service.dart';
import 'services/school_context.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _foregroundConfigured = false;
  String? _currentUserId;
  // Cache for user's subscribed groups to avoid redundant calls (best-effort)
  final Set<String> _groupSubs = <String>{};

  Future<void> init({required String? currentUserId}) async {
    // Always remember the current user id (for routing) even if already initialized
    if (currentUserId != null && currentUserId.isNotEmpty) {
      _currentUserId = currentUserId;
    }
    if (_initialized) return;

    // Local notifications init
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(payload: response.payload);
      },
    );
  // Handle taps on system notifications created by local plugin
  // Note: For additional payload routing, we could pass a payload, but here we always go to announcements.

    // Ensure Android notification channel exists for FCM + local notifications
    const AndroidNotificationChannel announcementsChannel = AndroidNotificationChannel(
      'announcements_channel',
      'Announcements',
      description: 'Notifications for new school announcements',
      importance: Importance.max,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(announcementsChannel);

    // Only configure presentation options; request permission later upon consent
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await _saveToken(_currentUserId!, newToken);
        if (kDebugMode) {
          // Helpful during testing
          // ignore: avoid_print
          print('FCM token refreshed for user \'${_currentUserId}\': $newToken');
        }
      }
    });

    if (!_foregroundConfigured) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notification = message.notification;
        final data = message.data;
        if (kDebugMode) {
          // ignore: avoid_print
          print('FCM foreground message: title="${notification?.title}", body="${notification?.body}", data=$data');
        }
        if (notification != null) {
          // Build a payload to route after tap
          String payload = 'open_announcements';
          if ((data['type'] ?? '') == 'group' && (data['groupId'] ?? '').toString().isNotEmpty) {
            final gid = data['groupId'].toString();
            final gname = (data['groupName'] ?? 'Group').toString();
            payload = 'open_group:$gid|$gname';
          }
          await _local.show(
            notification.hashCode,
            notification.title ?? (data['type'] == 'group' ? 'New group message' : 'New Announcement'),
            notification.body ?? 'Open the app to view details',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'announcements_channel',
                'Announcements',
                channelDescription: 'Notifications for new school announcements',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
            payload: payload,
          );
        }
      });
      _foregroundConfigured = true;
    }

    // Handle when the app is opened from a terminated state via an FCM notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(message: initialMessage);
    }

    // Handle when the app is in background and a user taps the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message: message);
    });

    _initialized = true;
  }

  void _handleNotificationTap({String? payload, RemoteMessage? message}) {
    String? type;
    String? gid;
    String? gname;
    if (message != null) {
      type = (message.data['type'] ?? '').toString();
      gid = (message.data['groupId'] ?? '').toString();
      gname = (message.data['groupName'] ?? '').toString();
    }
    if (payload != null && payload.startsWith('open_group:')) {
      final rest = payload.substring('open_group:'.length);
      final parts = rest.split('|');
      if (parts.isNotEmpty) gid = parts[0];
      if (parts.length > 1) gname = parts[1];
      type = 'group';
    }
    if (type == 'group' && gid != null && gid.isNotEmpty) {
      rootNavigatorKey.currentState?.pushNamed(
        '/groups/chat',
        arguments: {
          'groupId': gid,
          'name': (gname == null || gname.isEmpty) ? 'Group' : gname,
          'userId': _currentUserId ?? '',
        },
      );
      return;
    }
    // Default: open Current Page; it will show announcements tile and user groups
    rootNavigatorKey.currentState?.pushNamed(
      '/admin',
      arguments: {
        'userId': _currentUserId ?? '',
        'role': 'user',
      },
    );
  }

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // On Android 13+ returns authorized if granted; on iOS compare authorizationStatus
    return settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> enableForUser(String userId, {bool subscribeAll = true}) async {
    final granted = await _requestPermission();
    if (!granted) return false;
    final token = await _messaging.getToken();
    if (token != null) {
      _currentUserId = userId;
      await _saveToken(userId, token);
      if (subscribeAll) {
        try {
          await _messaging.subscribeToTopic('all');
          if (kDebugMode) {
            // ignore: avoid_print
            print('Subscribed $userId to topic "all"');
          }
        } catch (_) {}
      }
  // Also subscribe to all groups the user belongs to
  await subscribeToUserGroups(userId);
      // Mark consent on the user doc
      await _markConsent(userId, true);
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM token for $userId: $token');
      }
      return true;
    }
    return false;
  }

  Future<void> disableForUser(String userId, {bool unsubscribeAll = true}) async {
    // Optionally unsubscribe from the broadcast topic
    if (unsubscribeAll) {
      try {
        await _messaging.unsubscribeFromTopic('all');
        if (kDebugMode) {
          // ignore: avoid_print
          print('Unsubscribed $userId from topic "all"');
        }
      } catch (_) {}
    }
    // Mark consent off
    await _markConsent(userId, false);
    // Also mark the current device token as disabled for this user
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final users = FirebaseFirestore.instance.collection('users');
        final query = await users.where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: userId).limit(1).get();
        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.collection('devices').doc(token).set(
            {
              'enabled': false,
              'lastSeen': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final query = await users.where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: userId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final userRef = query.docs.first.reference;
        // Backward-compat field and a devices subcollection keyed by the token
        await userRef.set({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        await userRef.collection('devices').doc(token).set({
          'token': token,
          'platform': 'flutter',
          'enabled': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> subscribeToAll() async {
    try { await _messaging.subscribeToTopic('all'); } catch (_) {}
  }

  Future<void> unsubscribeFromAll() async {
    try { await _messaging.unsubscribeFromTopic('all'); } catch (_) {}
  }

  Future<void> subscribeToGroup(String groupId) async {
    if (groupId.isEmpty || _groupSubs.contains(groupId)) return;
    try {
      await _messaging.subscribeToTopic('group_$groupId');
      _groupSubs.add(groupId);
      if (kDebugMode) {
        // ignore: avoid_print
  print('Subscribed to group topic: group_$groupId'); // Cloud Function publishes here
      }
    } catch (_) {}
  }

  Future<void> unsubscribeFromGroup(String groupId) async {
    if (groupId.isEmpty) return;
    try {
      await _messaging.unsubscribeFromTopic('group_$groupId');
      _groupSubs.remove(groupId);
      if (kDebugMode) {
        // ignore: avoid_print
        print('Unsubscribed from group topic: group_$groupId');
      }
    } catch (_) {}
  }

  Future<void> subscribeToUserGroups(String userId) async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('groups')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .where('members', arrayContains: userId)
          .get();
      for (final d in qs.docs) {
        await subscribeToGroup(d.id);
      }
    } catch (_) {}
  }

  Future<void> unsubscribeFromUserGroups(String userId) async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('groups')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .where('members', arrayContains: userId)
          .get();
      for (final d in qs.docs) {
        await unsubscribeFromGroup(d.id);
      }
    } catch (_) {}
  }

  // Optional helper to show a local test notification for a group
  Future<void> showLocalGroupTest(String groupId, String groupName, String body) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'New message in $groupName',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'announcements_channel',
          'Announcements',
          channelDescription: 'Notifications for new school announcements',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: 'open_group:$groupId|$groupName',
    );
  }

  Future<void> _markConsent(String userId, bool enabled) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final query = await users.where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: userId).limit(1).get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.set({'notificationEnabled': enabled, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
