import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayAnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime holidayDate;
  final VoidCallback? onTap;
  final Function(String)? onReaction;

  const HolidayAnnouncementCard({
    Key? key,
    required this.data,
    required this.holidayDate,
    this.onTap,
    this.onReaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final daysUntil = holidayDate.difference(DateTime.now()).inDays;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;
    final isUpcoming = daysUntil > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isToday 
                ? const Color(0xFFFFD54F).withOpacity(0.2)
                : isTomorrow
                    ? const Color(0xFFFF8A65).withOpacity(0.2)
                    : const Color(0xFF81C784).withOpacity(0.2),
            isToday 
                ? const Color(0xFFFFCC02).withOpacity(0.3)
                : isTomorrow
                    ? const Color(0xFFFF7043).withOpacity(0.3)
                    : const Color(0xFF66BB6A).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday 
              ? const Color(0xFFFFD54F)
              : isTomorrow
                  ? const Color(0xFFFF8A65)
                  : const Color(0xFF81C784),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with holiday type badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday 
                            ? const Color(0xFFFFD54F)
                            : isTomorrow
                                ? const Color(0xFFFF8A65)
                                : const Color(0xFF81C784),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            size: 16,
                            color: isToday || isTomorrow ? Colors.white : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'HOLIDAY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isToday || isTomorrow ? Colors.white : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isUpcoming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isToday
                              ? 'TODAY'
                              : isTomorrow
                                  ? 'TOMORROW'
                                  : '$daysUntil DAYS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isToday 
                                ? const Color(0xFFFFD54F)
                                : isTomorrow
                                    ? const Color(0xFFFF8A65)
                                    : const Color(0xFF81C784),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Main content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendar Icon with Date
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isToday 
                            ? const Color(0xFFFFD54F)
                            : isTomorrow
                                ? const Color(0xFFFF8A65)
                                : const Color(0xFF81C784),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isToday 
                                ? const Color(0xFFFFD54F)
                                : isTomorrow
                                    ? const Color(0xFFFF8A65)
                                    : const Color(0xFF81C784)).withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('MMM').format(holidayDate).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateFormat('dd').format(holidayDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('EEE').format(holidayDate).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Holiday Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'Holiday',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isToday 
                                  ? const Color(0xFFE65100)
                                  : isTomorrow
                                      ? const Color(0xFFD84315)
                                      : const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(holidayDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (data['message'] != null && data['message'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['message'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Bottom section with reactions and timestamp
                Row(
                  children: [
                    // Timestamp
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data['timestamp'] != null
                          ? 'Posted ${_getRelativeTime((data['timestamp'] as Timestamp).toDate())}'
                          : 'Posted recently',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    
                    // Reactions
                    if (data['reactions'] != null && data['reactions'].isNotEmpty)
                      _buildReactionsSummary(data['reactions'] as Map<String, dynamic>),
                  ],
                ),
                
                // Special message for today's holiday
                if (isToday) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFFCC02)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Happy Holiday! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...reactionCounts.entries.take(3).map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              if (reactions.length > 0) ...[
                const SizedBox(width: 4),
                Text(
                  reactions.length.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
