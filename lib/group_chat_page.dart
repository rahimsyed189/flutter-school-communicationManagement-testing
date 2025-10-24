import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'dart:async';
import 'services/school_context.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;
  const GroupChatPage({Key? key, required this.groupId, required this.groupName, required this.currentUserId}) : super(key: key);

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<String> _members = const [];
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _groupStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _groupSub;
  // Cache userId -> display name for quick lookup in bubbles
  final Map<String, String> _nameCache = <String, String>{};

  // Selection & reactions (WhatsApp-like)
  bool _selectionActive = false;
  int? _selectedIndex;
  String? _selectedText;
  bool _selectedIsMine = false;
  DocumentReference<Map<String, dynamic>>? _selectedRef;
  OverlayEntry? _reactionsOverlay;

  // Background image settings
  String? _backgroundImageUrl;
  double _imageOpacity = 0.20;
  Color _gradientColor1 = const Color(0xFF667eea);
  Color _gradientColor2 = const Color(0xFF764ba2);

  @override
  void initState() {
    super.initState();
    _loadBackgroundSettings(); // Load background image
    _groupStream = FirebaseFirestore.instance.collection('groups').doc(widget.groupId).snapshots();
    _groupSub = _groupStream!.listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final m = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      if (!mounted) return;
      setState(() => _members = m);
      // Load names for members in background
      // ignore: unawaited_futures
      _fetchMemberNames(m);
  // Subscribe to group topic for notifications
  // ignore: unawaited_futures
  NotificationService.instance.subscribeToGroup(widget.groupId);
    });
  }

  Future<void> _loadBackgroundSettings() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      
      // Load from cache first (instant display)
      final prefs = await SharedPreferences.getInstance();
      String? cachedUrl = prefs.getString('background_url_$schoolId');
      final cachedOpacity = prefs.getDouble('background_opacity_$schoolId');
      final cachedColor1 = prefs.getInt('background_color1_$schoolId');
      final cachedColor2 = prefs.getInt('background_color2_$schoolId');
      
      // Fix common URL issues (double colon, double slash)
      if (cachedUrl != null) {
        cachedUrl = cachedUrl.replaceAll('https:://', 'https://').replaceAll('http:://', 'http://');
        if (cachedUrl != prefs.getString('background_url_$schoolId')) {
          await prefs.setString('background_url_$schoolId', cachedUrl);
        }
      }
      
      if (cachedUrl != null) {
        _backgroundImageUrl = cachedUrl;
      }
      if (cachedOpacity != null) {
        _imageOpacity = cachedOpacity;
      }
      if (cachedColor1 != null) {
        _gradientColor1 = Color(cachedColor1);
      }
      if (cachedColor2 != null) {
        _gradientColor2 = Color(cachedColor2);
      }
      
      if (mounted) setState(() {}); // Show cached data immediately
      
      // Then load from Firestore (to get latest)
      final bgDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background')
          .get();
      
      if (bgDoc.exists && bgDoc.data()?['imageUrl'] != null) {
        String firestoreUrl = bgDoc.data()!['imageUrl'];
        
        // Fix common URL issues
        firestoreUrl = firestoreUrl.replaceAll('https:://', 'https://').replaceAll('http:://', 'http://');
        
        _backgroundImageUrl = firestoreUrl;
        
        // Update cache if changed
        if (cachedUrl != firestoreUrl) {
          await prefs.setString('background_url_$schoolId', firestoreUrl);
        }
        
        // If URL was bad in Firestore, fix it
        if (firestoreUrl != bgDoc.data()!['imageUrl']) {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('config')
              .doc('background')
              .update({'imageUrl': firestoreUrl});
        }
      }
      
      // Load opacity
      final opacityDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_opacity')
          .get();
      
      if (opacityDoc.exists) {
        final firestoreOpacity = opacityDoc.data()?['opacity'] ?? 0.20;
        _imageOpacity = firestoreOpacity;
        
        // Update cache
        if (cachedOpacity != firestoreOpacity) {
          await prefs.setDouble('background_opacity_$schoolId', firestoreOpacity);
        }
      }
      
      // Load gradient colors
      final gradientDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_gradient')
          .get();
      
      if (gradientDoc.exists) {
        final data = gradientDoc.data()!;
        final color1 = Color(data['color1'] ?? 0xFF667eea);
        final color2 = Color(data['color2'] ?? 0xFF764ba2);
        _gradientColor1 = color1;
        _gradientColor2 = color2;
        
        // Update cache
        if (cachedColor1 != color1.value || cachedColor2 != color2.value) {
          await prefs.setInt('background_color1_$schoolId', color1.value);
          await prefs.setInt('background_color2_$schoolId', color2.value);
        }
      }
      
      if (mounted) setState(() {}); // Update with latest data
    } catch (e) {
      debugPrint('Failed to load background settings: $e');
    }
  }

  Future<void> _fetchMemberNames(List<String> ids) async {
    if (ids.isEmpty) return;
    // Fetch in chunks of 10 due to whereIn limit
  const chunk = 10;
  for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, (i + chunk > ids.length) ? ids.length : i + chunk);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', whereIn: part)
            .get();
        bool changed = false;
        for (final d in snap.docs) {
          final id = (d['userId'] ?? '').toString();
          final name = (d['name'] ?? '').toString();
          if (id.isNotEmpty && (_nameCache[id] ?? '') != name && name.isNotEmpty) {
            _nameCache[id] = name;
            changed = true;
          }
        }
        if (changed && mounted) setState(() {});
      } catch (_) {
        // ignore failures for some chunks
      }
    }
  }

  String _displayName(String userId) => _nameCache[userId] ?? userId;

  Future<void> _setReaction(String emoji) async {
    final ref = _selectedRef;
    if (ref == null) return;
    try {
      await ref.update({'reactions.${widget.currentUserId}': emoji});
    } catch (e) {
      try {
        await ref.set({'reactions': {widget.currentUserId: emoji}}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  void _showReactionsOverlay(Offset globalPosition) {
    _removeReactionsOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final media = MediaQuery.of(context);
    const margin = 12.0;
    const overlayWidth = 208.0;
    final dx = globalPosition.dx;
    final dy = (globalPosition.dy - 56).clamp(kToolbarHeight + media.padding.top + margin, media.size.height - 120.0);
    final left = (dx - overlayWidth / 2).clamp(margin, media.size.width - margin - overlayWidth);

    _reactionsOverlay = OverlayEntry(
      builder: (_) => Positioned(
        left: left as double,
        top: (dy - 48) as double,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: overlayWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in ['👍','❤️','😂','😮','😢','🙏'])
                    InkWell(
                      onTap: () async {
                        await _setReaction(e);
                        _exitSelection();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_reactionsOverlay!);
  }

  void _removeReactionsOverlay() {
    _reactionsOverlay?.remove();
    _reactionsOverlay = null;
  }

  void _enterSelection({
    required LongPressStartDetails details,
    required bool isMine,
    required String message,
    required DocumentReference<Map<String, dynamic>> ref,
    required int index,
  }) {
    setState(() {
      _selectionActive = true;
      _selectedIndex = index;
      _selectedIsMine = isMine;
      _selectedText = message;
      _selectedRef = ref;
    });
    _showReactionsOverlay(details.globalPosition);
  }

  void _exitSelection() {
    _removeReactionsOverlay();
    if (!_selectionActive) return;
    setState(() {
      _selectionActive = false;
      _selectedIndex = null;
      _selectedIsMine = false;
      _selectedText = null;
      _selectedRef = null;
    });
  }

  String _formatDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = that.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return '${that.day.toString().padLeft(2, '0')}/${that.month.toString().padLeft(2, '0')}/${that.year}';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final col = FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('messages');
    await col.add({
      'sender': widget.currentUserId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  // Note: Cloud Function will pick this up to notify topic `group_${widget.groupId}`
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectionActive) {
          _exitSelection();
          return false;
        }
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gradientColor1, _gradientColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _backgroundImageUrl != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _imageOpacity,
                      child: CachedNetworkImage(
                        imageUrl: _backgroundImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(),
                        errorWidget: (context, url, error) => Container(),
                      ),
                    ),
                  ),
                  _buildScaffold(),
                ],
              )
            : _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _selectionActive ? const Text('1 selected') : Text(widget.groupName),
        leading: _selectionActive ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelection) : null,
          actions: [
            if (_selectionActive) ...[
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'copy') {
                    if (_selectedText != null) {
                      await Clipboard.setData(ClipboardData(text: _selectedText!));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      }
                    }
                    _exitSelection();
                  } else if (v == 'delete' && _selectedIsMine) {
                    final ref = _selectedRef;
                    if (ref != null) {
                      try { await ref.delete(); } catch (_) {}
                    }
                    _exitSelection();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  if (_selectedIsMine) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Members',
              onPressed: () async {
              // Fetch user details for members and show in bottom sheet
              if (_members.isEmpty) {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text('No members'))),
                );
                return;
              }
              // Firestore whereIn supports up to 10 items; fetch in chunks
              final known = <String, String>{};
              const chunk = 10;
              for (var i = 0; i < _members.length; i += chunk) {
                final part = _members.sublist(i, i + chunk > _members.length ? _members.length : i + chunk);
                try {
                  final usersSnap = await FirebaseFirestore.instance
                      .collection('users')
                      .where('userId', whereIn: part)
                      .get();
                  for (final d in usersSnap.docs) {
                    known[(d['userId'] ?? '').toString()] = (d['name'] ?? '').toString();
                  }
                } catch (_) {
                  // ignore chunk fetch errors
                }
              }
              if (!mounted) return;
              final entries = _members.map((id) => MapEntry(id, known[id] ?? id)).toList();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.group),
                        title: Text('Members (${entries.length})'),
                      ),
                      const Divider(height: 0),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
                          itemBuilder: (ctx, i) {
                            final id = entries[i].key;
                            final name = entries[i].value;
                            final initial = (name.isNotEmpty
                                    ? name[0]
                                    : (id.isNotEmpty ? id[0] : '?'))
                                .toUpperCase();
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.blueGrey.shade200,
                                child: Text(initial),
                              ),
                              title: Text(name.isNotEmpty ? name : id),
                              subtitle: Text(id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
              },
            ),
        ],
      ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) {
                      _scroll.jumpTo(_scroll.position.maxScrollExtent);
                    }
                  });
                  final bottomPad = 96.0 + MediaQuery.of(context).padding.bottom;
                  return ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.only(bottom: bottomPad),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final isMine = data['sender'] == widget.currentUserId;
                      final message = (data['message'] ?? '').toString();
                      final ts = data['timestamp'];
                      DateTime? time;
                      if (ts is Timestamp) time = ts.toDate();
                      final timeStr = time != null ? TimeOfDay.fromDateTime(time).format(context) : '';

                      // Day header
                      Widget? dayHeader;
                      if (time != null) {
                        final prevTs = i > 0 ? docs[i - 1].data()['timestamp'] : null;
                        DateTime? prevTime;
                        if (prevTs is Timestamp) prevTime = prevTs.toDate();
                        final needHeader = prevTime == null ||
                            DateTime(prevTime.year, prevTime.month, prevTime.day) != DateTime(time.year, time.month, time.day);
                        if (needHeader) {
                          dayHeader = Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_formatDay(time), style: const TextStyle(color: Colors.black87, fontSize: 12)),
                            ),
                          );
                        }
                      }

                      final ref = docs[i].reference;
                      final isSelected = _selectionActive && _selectedIndex == i;
                      final reactions = (data['reactions'] as Map<String, dynamic>?) ?? const {};
                      final Map<String, int> reactionCounts = {};
                      reactions.values.forEach((val) {
                        final emo = val?.toString() ?? '';
                        if (emo.isEmpty) return;
                        reactionCounts[emo] = (reactionCounts[emo] ?? 0) + 1;
                      });

                      final bubble = Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPressStart: (details) {
                            _enterSelection(
                              details: details,
                              isMine: isMine,
                              message: message,
                              ref: ref,
                              index: i,
                            );
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isMine ? const Color(0xFFA5D6A7) : const Color(0xFFEDEDED))
                                    : (isMine ? const Color(0xFFDFF7C6) : const Color(0xFFFFFFFF)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                                  bottomRight: Radius.circular(isMine ? 4 : 16),
                                ),
                                border: isSelected ? Border.all(color: Colors.teal.shade200) : null,
                                boxShadow: const [BoxShadow(blurRadius: 0.6, color: Colors.black12)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMine)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        _displayName((data['sender'] ?? '').toString()),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                                      ),
                                    ),
                                  SelectableText(
                                    message,
                                    style: const TextStyle(fontSize: 16, height: 1.3),
                                    cursorWidth: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                        if (isMine) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check, size: 14, color: Colors.black45),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (reactionCounts.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: const [BoxShadow(blurRadius: 0.3, color: Colors.black12)],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final entry in reactionCounts.entries) ...[
                                              Text(entry.key, style: const TextStyle(fontSize: 14)),
                                              if (entry.value > 1)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 2, right: 6),
                                                  child: Text('${entry.value}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                )
                                              else
                                                const SizedBox(width: 6),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      if (dayHeader != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [dayHeader!, bubble],
                        );
                      }
                      return bubble;
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    color: Colors.black54,
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.teal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.black54,
                    onPressed: () {},
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send), color: Colors.teal),
                ],
              ),
              ),
            )
          ],
        ),
      );
  }

  @override
  void dispose() {
  try { _groupSub?.cancel(); } catch (_) {}
    _ctrl.dispose();
    _scroll.dispose();
    _removeReactionsOverlay();
    super.dispose();
  }
}
