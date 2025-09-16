import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// PTM (Parent Teacher Meeting) Announcement Card
class PTMAnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final Function(String)? onReaction;

  const PTMAnnouncementCard({
    Key? key,
    required this.data,
    this.onTap,
    this.onReaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get PTM data
    final ptmDate = data['ptmDate'] != null ? (data['ptmDate'] as Timestamp).toDate() : DateTime.now();
    final rawStartTime = data['ptmStartTime'] ?? '4:00';
    final rawEndTime = data['ptmEndTime'] ?? '6:00';
    final startTime = _formatTimeToAMPM(rawStartTime);
    final endTime = _formatTimeToAMPM(rawEndTime);
    final venue = data['venue'] ?? 'School Auditorium';
    final phone = data['phone'] ?? '';
    final colorSchemeIndex = data['colorScheme'] ?? 0;
    final customTag = data['tag'] ?? 'PTM';
    final title = data['title'] ?? 'Parent Teacher Meeting';
    final description = data['description'] ?? 'Work together for a better future';

    // Color schemes matching template
    final List<Map<String, dynamic>> colorSchemes = [
      {
        'primary': Color(0xFF1F5FA6),
        'secondary': Color(0xFFF2B631),
        'accent': Color(0xFF2C3E50),
        'background': [Color(0xFFFBFBFF), Color(0xFFEEF6FF)],
        'wood': [Color(0xFFF7E6D0), Color(0xFFF0CFA2)],
        'text': Color(0xFF0F1720),
        'muted': Color(0xFF6B6F76),
      },
      {
        'primary': Color(0xFF2E7D32),
        'secondary': Color(0xFF66BB6A),
        'accent': Color(0xFF1B5E20),
        'background': [Color(0xFFF8FFF8), Color(0xFFE8F5E8)],
        'wood': [Color(0xFFE8D5C2), Color(0xFFD7C3A8)],
        'text': Color(0xFF1B5E20),
        'muted': Color(0xFF757575),
      },
      {
        'primary': Color(0xFF7B1FA2),
        'secondary': Color(0xFFBA68C8),
        'accent': Color(0xFF4A148C),
        'background': [Color(0xFFFCF8FF), Color(0xFFF3E5F5)],
        'wood': [Color(0xFFE6D7F0), Color(0xFFD1C4E9)],
        'text': Color(0xFF4A148C),
        'muted': Color(0xFF757575),
      },
    ];

    final colorScheme = colorSchemes[colorSchemeIndex.clamp(0, colorSchemes.length - 1)];

    // Calculate days until PTM
    final now = DateTime.now();
    final ptmDateOnly = DateTime(ptmDate.year, ptmDate.month, ptmDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    final daysUntil = ptmDateOnly.difference(nowDateOnly).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colorScheme['background'],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [

                    // Wooden board
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: colorScheme['wood'],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: colorScheme['text'],
                                letterSpacing: 1.2,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme['muted'],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info card - Date and Time only
                    Center(
                      child: _buildInfoCard(
                        icon: Icons.calendar_month,
                        title: DateFormat('EEEE, dd MMMM').format(ptmDate),
                        subtitle: '$startTime to $endTime',
                        colorScheme: colorScheme,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Note section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme['muted'].withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.note_alt_outlined,
                                size: 16,
                                color: colorScheme['primary'],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Note:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme['primary'],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please arrive 10 minutes early. Bring your child\'s progress report and any specific concerns you\'d like to discuss.',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme['text'],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Countdown
                    Container(
                      child: Text(
                        daysUntil > 0 
                            ? '⏳ $daysUntil days remaining until PTM!'
                            : daysUntil == 0
                                ? '🎉 PTM is today!'
                                : daysUntil == -1
                                    ? '📋 PTM was yesterday'
                                    : '📋 PTM was ${daysUntil.abs()} days ago',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: daysUntil >= 0 ? colorScheme['primary'] : colorScheme['muted'],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Ribbon Tag
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  height: 28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main ribbon body
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colorScheme['primary'],
                              colorScheme['primary'].withOpacity(0.9),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                            topRight: Radius.circular(2),
                            bottomRight: Radius.circular(2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Metal eyelet
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  center: Alignment(-0.3, -0.3),
                                  colors: [
                                    Colors.white,
                                    Color(0x99FFFFFF),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.3, 0.8],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme['secondary'],
                                        colorScheme['secondary'].withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Text
                            Text(
                              customTag.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 1,
                                    offset: Offset(0, 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Folded corner/notch
                      ClipPath(
                        clipper: _HorizontalNotchClipper(),
                        child: Container(
                          width: 12,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                colorScheme['primary'].withOpacity(0.8),
                                colorScheme['secondary'].withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Map<String, dynamic> colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colorScheme['secondary'],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme['muted'],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format time to AM/PM
  String _formatTimeToAMPM(String time24) {
    try {
      // Parse the time (assuming format like "16:00" or "4:00")
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      String period = 'AM';
      if (hour >= 12) {
        period = 'PM';
        if (hour > 12) hour -= 12;
      }
      if (hour == 0) hour = 12;
      
      String minuteStr = minute.toString().padLeft(2, '0');
      return '$hour:$minuteStr $period';
    } catch (e) {
      return time24; // Return original if parsing fails
    }
  }
}

// Custom clipper for horizontal ribbon tail
class _HorizontalNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.8, 0);
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}