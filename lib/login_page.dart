import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final String? prefillUserId;
  final String? prefillPassword;
  const LoginPage({super.key, required this.onLoginSuccess, this.prefillUserId, this.prefillPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _wantsNotifications = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _applyPrefill();
  }

  Future<void> _applyPrefill() async {
    // Prefer values passed to the screen
    if ((widget.prefillUserId ?? '').isNotEmpty) {
      _userIdController.text = widget.prefillUserId!;
    }
    if ((widget.prefillPassword ?? '').isNotEmpty) {
      _passwordController.text = widget.prefillPassword!;
    }
    // If still empty, try pending saved values
    if (_userIdController.text.isEmpty || _passwordController.text.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (_userIdController.text.isEmpty) {
        final v = prefs.getString('pending_userId');
        if (v != null && v.isNotEmpty) _userIdController.text = v;
      }
      if (_passwordController.text.isEmpty) {
        final v = prefs.getString('pending_password');
        if (v != null && v.isNotEmpty) _passwordController.text = v;
      }
      // If still empty, fallback to last successful login creds
      if (_userIdController.text.isEmpty) {
        final v = prefs.getString('remember_userId');
        if (v != null && v.isNotEmpty) _userIdController.text = v;
      }
      if (_passwordController.text.isEmpty) {
        final v = prefs.getString('remember_password');
        if (v != null && v.isNotEmpty) _passwordController.text = v;
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();
    try {
      // If there's a pending registration with same phone, block login until approved (unless user already exists)
      try {
        final pending = await FirebaseFirestore.instance
            .collection('registrations')
            .where('phone', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (pending.docs.isNotEmpty) {
          final existing = await FirebaseFirestore.instance
              .collection('users')
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();
          if (existing.docs.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Your registration is pending approval')),
              );
            }
            return;
          }
        }
      } catch (_) {}

      // Fetch user by ID first to check reset status
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid credentials')),
          );
        }
        return;
      }

      final userData = Map<String, dynamic>.from(userQuery.docs.first.data());

      // If admin required password reset, allow with any password and force change now
      if ((userData['mustChangePassword'] ?? false) == true) {
        final changed = await Navigator.pushNamed(
          context,
          '/forcePassword',
          arguments: {'userId': userData['userId']},
        );
        if (changed != true) {
          return;
        }
        // reload user
        final refreshed = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: userData['userId'])
            .limit(1)
            .get();
        if (refreshed.docs.isNotEmpty) {
          userData
            ..clear()
            ..addAll(refreshed.docs.first.data());
        }
      } else {
        // Otherwise, validate password normally
        if ((userData['password'] ?? '').toString() != password) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid credentials')),
            );
          }
          return;
        }
      }

      // Notifications toggle
      if (_wantsNotifications) {
        await NotificationService.instance.enableForUser(userData['userId']);
      }

      // Persist minimal session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_userId', userData['userId'] ?? userId);
      await prefs.setString('session_role', (userData['role'] ?? 'user').toString());
      await prefs.setString('session_name', (userData['name'] ?? '').toString());

      // Remember creds for next time if opted-in (plain text per requirement)
      if (_remember) {
        await prefs.setString('remember_userId', userId);
        final rememberPass = (userData['password']?.toString().isNotEmpty == true)
            ? userData['password'].toString()
            : password;
        await prefs.setString('remember_password', rememberPass);
      }

      // Clear any pending prefill once logged in
      await prefs.remove('pending_userId');
      await prefs.remove('pending_password');

      // Route to home (admin page handles role-specific UI)
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/admin',
          arguments: {
            'userId': userData['userId'],
            'role': userData['role'] ?? 'user',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _wantsNotifications,
                  onChanged: (v) => setState(() => _wantsNotifications = v ?? true),
                ),
                const Expanded(child: Text('Enable notifications for announcements')),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? true),
                ),
                const Expanded(child: Text('Remember ID and Password on this device')),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
