import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolHolidayCard extends StatelessWidget {
  // Light gradient color schemes (same as template)
  static const List<Map<String, dynamic>> _colorSchemes = [
    {
      'name': 'Light Blue',
      'background': [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
      'tag': Color(0xFF42A5F5),
      'ribbon': Color(0xFF1976D2),
    },
    {
      'name': 'Light Green', 
      'background': [Color(0xFFE8F5E8), Color(0xFFFFFFFF)],
      'tag': Color(0xFF66BB6A),
      'ribbon': Color(0xFF388E3C),
    },
    {
      'name': 'Light Orange',
      'background': [Color(0xFFFFF3E0), Color(0xFFFFFFFF)],
      'tag': Color(0xFFFF9800),
      'ribbon': Color(0xFFE65100),
    },
    {
      'name': 'Light Purple',
      'background': [Color(0xFFF3E5F5), Color(0xFFFFFFFF)],
      'tag': Color(0xFFAB47BC),
      'ribbon': Color(0xFF7B1FA2),
    },
    {
      'name': 'Light Pink',
      'background': [Color(0xFFFCE4EC), Color(0xFFFFFFFF)],
      'tag': Color(0xFFEC407A),
      'ribbon': Color(0xFFC2185B),
    },
    {
      'name': 'Light Teal',
      'background': [Color(0xFFE0F2F1), Color(0xFFFFFFFF)],
      'tag': Color(0xFF26A69A),
      'ribbon': Color(0xFF00695C),
    },
  ];
  final Map<String, dynamic> data;
  final DateTime holidayDate;
  final VoidCallback? onTap;
  final Function(String)? onReaction;

  const SchoolHolidayCard({
    Key? key,
    required this.data,
    required this.holidayDate,
    this.onTap,
    this.onReaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isHolidayRange = data['isHolidayRange'] ?? false;
    final holidayStartDate = data['holidayStartDate'] != null 
        ? (data['holidayStartDate'] as Timestamp).toDate() 
        : holidayDate;
    final holidayEndDate = data['holidayEndDate'] != null 
        ? (data['holidayEndDate'] as Timestamp).toDate() 
        : holidayDate;
    final totalDays = data['totalDays'] ?? 1;
    
    final daysUntil = holidayStartDate.difference(DateTime.now()).inDays;
    
    // Get color scheme (default to 0 if not set)
    final colorSchemeIndex = (data['colorScheme'] as int?) ?? 0;
    final colorScheme = _colorSchemes[colorSchemeIndex.clamp(0, _colorSchemes.length - 1)];
    
    // Get custom tag (default to 'HOLIDAY' if not set)
    final customTag = (data['tag'] as String?) ?? 'HOLIDAY';
    
    // Check if this is a new/unseen message (posted within last 24 hours)
    final isNewMessage = data['timestamp'] != null 
        ? DateTime.now().difference((data['timestamp'] as Timestamp).toDate()).inHours < 24
        : false;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Info Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: colorScheme['background'],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      colorScheme['tag'],
                                      colorScheme['tag'].withOpacity(0.9),
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
                                                Color(0xFFf9d976),
                                                Color(0xFFf39c12),
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
                                        colorScheme['tag'].withOpacity(0.8),
                                        colorScheme['ribbon'],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Small bold title below tag
                      Text(
                        '${data['title'] ?? 'Holiday'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      

                      
                      // Description
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF333333),
                            height: 1.4,
                            fontFamily: 'Segoe UI',
                          ),
                          children: [
                            if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                              TextSpan(
                                text: '${data['description']}\n\n',
                                style: const TextStyle(
                                  color: Color(0xFF666666), // Different color for description
                                  fontWeight: FontWeight.bold, // Made bold
                                ),
                              ),
                            ],
                            if (isHolidayRange) ...[
                              const TextSpan(text: 'From '),
                              TextSpan(
                                text: DateFormat('dd MMM').format(holidayStartDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' To '),
                              TextSpan(
                                text: DateFormat('dd MMM').format(holidayEndDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: '.'),
                            ] else ...[
                              const TextSpan(text: 'On '),
                              TextSpan(
                                text: DateFormat('dd MMMM yyyy').format(holidayDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                            if (data['message'] != null && data['message'].toString().isNotEmpty) ...[
                              const TextSpan(text: '\n\n'),
                              TextSpan(text: data['message']),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Countdown
                      Container(
                        child: Text(
                          daysUntil > 0 
                              ? '⏳ $daysUntil days remaining until holidays begin!'
                              : daysUntil == 0
                                  ? '🎉 Holiday starts today!'
                                  : daysUntil == -1
                                      ? '🎉 Holiday started yesterday!'
                                      : '📅 Holiday was ${daysUntil.abs()} days ago',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0066cc),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Calendar Section
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFeeeeee), width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Calendar Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme['ribbon'],
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy').format(isHolidayRange ? holidayStartDate : holidayDate),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      
                      // Calendar Grid
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        child: _buildCalendarGrid(
                          isHolidayRange ? holidayStartDate : holidayDate,
                          isHolidayRange ? holidayEndDate : holidayDate,
                          isHolidayRange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom section with reactions and timestamp
                if (data['reactions'] != null && data['reactions'].isNotEmpty || data['timestamp'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Timestamp
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          data['timestamp'] != null
                              ? 'Posted ${_getRelativeTime((data['timestamp'] as Timestamp).toDate())}'
                              : 'Posted recently',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        
                        // Reactions
                        if (data['reactions'] != null && data['reactions'].isNotEmpty)
                          _buildReactionsSummary(data['reactions'] as Map<String, dynamic>),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime startDate, DateTime endDate, bool isRange) {
    final DateTime firstDayOfMonth = DateTime(startDate.year, startDate.month, 1);
    final DateTime lastDayOfMonth = DateTime(startDate.year, startDate.month + 1, 0);
    final int firstWeekday = firstDayOfMonth.weekday % 7; // Convert to 0=Sunday, 1=Monday, etc.
    
    // Day headers
    const List<String> dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    List<Widget> calendarCells = [];
    
    // Add day headers
    for (String day in dayHeaders) {
      calendarCells.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4), // Reduced from 6
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
              fontSize: 11, // Reduced from 12
            ),
          ),
        ),
      );
    }
    
    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstWeekday; i++) {
      calendarCells.add(Container());
    }
    
    // Add days of the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final DateTime currentDate = DateTime(startDate.year, startDate.month, day);
      final bool isHolidayDay = isRange
          ? (currentDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
             currentDate.isBefore(endDate.add(const Duration(days: 1))))
          : currentDate.day == startDate.day && currentDate.month == startDate.month;
      
      calendarCells.add(
        Container(
          margin: const EdgeInsets.all(0.5), // Reduced margin
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Date container
              Container(
                width: 28, // Reduced from 32
                height: 28, // Reduced from 32
                decoration: BoxDecoration(
                  color: isHolidayDay ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14), // Adjusted for smaller size
                  border: isHolidayDay 
                      ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isHolidayDay ? Colors.white : const Color(0xFF333333),
                      fontWeight: isHolidayDay ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12, // Reduced from 13
                    ),
                  ),
                ),
              ),
              
              // Holiday tag
              if (isHolidayDay)
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'H',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 240), // Reduced calendar height
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2, // Make cells slightly more compact
        mainAxisSpacing: 2, // Reduced gap
        crossAxisSpacing: 2, // Reduced gap
        children: calendarCells,
      ),
    );
  }

  Widget _buildReactionsSummary(Map<String, dynamic> reactions) {
    final reactionCounts = <String, int>{};
    for (final reaction in reactions.values) {
      final emoji = reaction.toString();
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    if (reactionCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...reactionCounts.entries.take(3).map((entry) => 
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          if (reactions.length > 0) ...[
            const SizedBox(width: 4),
            Text(
              reactions.length.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0066cc),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(timestamp);
    }
  }
}

// Custom clipper for ribbon notch/tail
class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.75, size.height);
    path.lineTo(size.width * 0.25, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
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
