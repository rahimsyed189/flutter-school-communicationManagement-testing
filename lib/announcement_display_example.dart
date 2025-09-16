import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'school_media_card_widget.dart';
import 'multi_r2_media_uploader_page.dart' show MediaType;

/// Example of how to use SchoolMediaCardWidget to display announcements
/// with media in your announcements feed
class AnnouncementDisplayExample extends StatelessWidget {
  const AnnouncementDisplayExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('School Announcements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0B1220),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Replace 'announcements' with your actual collection name
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcements = snapshot.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final doc = announcements[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildAnnouncementCard(data),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcementData) {
    // Convert Firestore data to MediaItem objects
    final List<MediaItem> mediaItems = [];
    
    // Assuming your Firestore structure has a 'media' array field
    final mediaList = announcementData['media'] as List<dynamic>? ?? [];
    
    for (final mediaData in mediaList) {
      final mediaMap = mediaData as Map<String, dynamic>;
      
      mediaItems.add(MediaItem(
        type: _determineMediaType(mediaMap),
        thumbnailPath: mediaMap['thumbnailUrl'], // Use URL instead of local path
        fileName: mediaMap['fileName'] ?? 'Unknown',
        duration: _parseDuration(mediaMap['duration']), // Parse duration string to Duration
        downloadUrl: mediaMap['downloadUrl'], // For downloading/viewing
        onTap: () => _openMediaViewer(mediaMap), // Handle media viewing
      ));
    }

    return Center(
      child: SchoolMediaCardWidget(
        title: announcementData['title'] ?? 'School Announcement',
        subtitle: announcementData['subtitle'] ?? 'Important Information',
        senderInfo: announcementData['senderInfo'] ?? 'School Administration',
        recipientInfo: announcementData['recipientInfo'] ?? 'For: All Students',
        timestamp: (announcementData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        mediaItems: mediaItems,
        isUploadMode: false, // This is display mode, not upload mode
        // No upload controls needed for announcements
      ),
    );
  }

  void _openMediaViewer(Map<String, dynamic> mediaData) {
    // Implement your media viewer here
    // You could use a package like photo_view for images
    // or video_player for videos
    print('Opening media: ${mediaData['fileName']}');
    // Example: Navigator.push to a full-screen media viewer
  }

  MediaType _determineMediaType(Map<String, dynamic> mediaData) {
    final type = mediaData['type']?.toString().toLowerCase();
    final fileName = mediaData['fileName']?.toString().toLowerCase() ?? '';
    final mimeType = mediaData['mime_type']?.toString().toLowerCase() ?? '';
    
    if (type == 'video' || fileName.contains('.mp4') || fileName.contains('.mov') || mimeType.startsWith('video/')) {
      return MediaType.video;
    }
    
    return MediaType.photo; // Default to photo
  }

  Duration? _parseDuration(dynamic duration) {
    if (duration is Duration) {
      return duration;
    } else if (duration is String) {
      // Parse duration string like "3:45" to Duration
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return Duration(minutes: minutes, seconds: seconds);
      }
    } else if (duration is int) {
      return Duration(seconds: duration);
    }
    
    return null;
  }
}

/// Extension to show how you can customize the card for different announcement types
class CustomAnnouncementCards extends StatelessWidget {
  const CustomAnnouncementCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency announcement
          _buildEmergencyCard(),
          const SizedBox(height: 24),
          
          // Regular announcement with photos
          _buildPhotoAnnouncementCard(),
          const SizedBox(height: 24),
          
          // Video announcement
          _buildVideoAnnouncementCard(),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Center(
      child: SchoolMediaCardWidget(
        title: '🚨 Emergency Notice',
        subtitle: 'Important Safety Information',
        senderInfo: 'Emergency Management',
        recipientInfo: 'For: All Staff & Students',
        timestamp: DateTime.now(),
        mediaItems: [], // No media for text-only emergency
        isUploadMode: false,
        // You could add custom styling here for emergency cards
      ),
    );
  }

  Widget _buildPhotoAnnouncementCard() {
    final photoItems = [
      MediaItem(
        type: MediaType.photo,
        thumbnailPath: 'https://example.com/thumbnail1.jpg',
        fileName: 'school_event_1.jpg',
        downloadUrl: 'https://example.com/full_image1.jpg',
        onTap: () => print('View photo 1'),
      ),
      MediaItem(
        type: MediaType.photo,
        thumbnailPath: 'https://example.com/thumbnail2.jpg',
        fileName: 'school_event_2.jpg',
        downloadUrl: 'https://example.com/full_image2.jpg',
        onTap: () => print('View photo 2'),
      ),
    ];

    return Center(
      child: SchoolMediaCardWidget(
        title: '📸 School Event Photos',
        subtitle: 'Annual Science Fair 2025',
        senderInfo: 'Photography Club',
        recipientInfo: 'For: All Students & Parents',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        mediaItems: photoItems,
        isUploadMode: false,
      ),
    );
  }

  Widget _buildVideoAnnouncementCard() {
    final videoItems = [
      MediaItem(
        type: MediaType.video,
        thumbnailPath: 'https://example.com/video_thumbnail.jpg',
        fileName: 'principal_message.mp4',
        duration: const Duration(minutes: 3, seconds: 45),
        downloadUrl: 'https://example.com/principal_message.mp4',
        onTap: () => print('Play video'),
      ),
    ];

    return Center(
      child: SchoolMediaCardWidget(
        title: '🎥 Principal\'s Message',
        subtitle: 'Monthly Update & Announcements',
        senderInfo: 'Principal Office',
        recipientInfo: 'For: All Community Members',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        mediaItems: videoItems,
        isUploadMode: false,
      ),
    );
  }
}

/// Helper class for integrating with your existing announcement system
class AnnouncementIntegration {
  
  /// Convert your existing announcement data structure to work with SchoolMediaCardWidget
  static Widget buildAnnouncementCard({
    required Map<String, dynamic> announcementData,
    VoidCallback? onTap,
  }) {
    // Extract media items from your data structure
    final mediaItems = _extractMediaItems(announcementData);
    
    return GestureDetector(
      onTap: onTap,
      child: SchoolMediaCardWidget(
        title: announcementData['title'] ?? 'Announcement',
        subtitle: announcementData['description'] ?? '',
        senderInfo: announcementData['author'] ?? 'School Administration',
        recipientInfo: _formatRecipientInfo(announcementData),
        timestamp: _parseTimestamp(announcementData['created_at']),
        mediaItems: mediaItems,
        isUploadMode: false,
      ),
    );
  }

  static List<MediaItem> _extractMediaItems(Map<String, dynamic> data) {
    final mediaItems = <MediaItem>[];
    
    // Handle different media field names that might exist in your data
    final mediaFields = ['media', 'attachments', 'files', 'images', 'videos'];
    
    for (final fieldName in mediaFields) {
      final mediaList = data[fieldName] as List<dynamic>? ?? [];
      
      for (final media in mediaList) {
        if (media is Map<String, dynamic>) {
          mediaItems.add(_createMediaItem(media));
        }
      }
    }
    
    return mediaItems;
  }

  static MediaItem _createMediaItem(Map<String, dynamic> mediaData) {
    return MediaItem(
      type: _determineMediaType(mediaData),
      thumbnailPath: mediaData['thumbnail_url'] ?? mediaData['url'],
      fileName: mediaData['file_name'] ?? mediaData['name'] ?? 'Unknown',
      duration: mediaData['duration'],
      downloadUrl: mediaData['download_url'] ?? mediaData['url'],
      onTap: () => _handleMediaTap(mediaData),
    );
  }

  static MediaType _determineMediaType(Map<String, dynamic> mediaData) {
    final type = mediaData['type']?.toString().toLowerCase();
    final fileName = mediaData['file_name']?.toString().toLowerCase() ?? '';
    final mimeType = mediaData['mime_type']?.toString().toLowerCase() ?? '';
    
    if (type == 'video' || fileName.contains('.mp4') || fileName.contains('.mov') || mimeType.startsWith('video/')) {
      return MediaType.video;
    }
    
    return MediaType.photo; // Default to photo
  }

  static String _formatRecipientInfo(Map<String, dynamic> data) {
    final audience = data['audience'] ?? data['recipients'] ?? data['target_users'];
    
    if (audience is String) {
      return 'For: $audience';
    } else if (audience is List) {
      return 'For: ${audience.join(', ')}';
    }
    
    return 'For: All Users';
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    
    return DateTime.now();
  }

  static void _handleMediaTap(Map<String, dynamic> mediaData) {
    // Implement your media viewing logic here
    print('Opening media: ${mediaData['file_name']}');
    // Example: Open in full-screen viewer, download, etc.
  }
}
