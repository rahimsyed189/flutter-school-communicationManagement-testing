import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist and restore the last visited route
/// This allows the app to remember and restore the last page a user was viewing when they reopen the app after closing it.
class RoutePersistenceService {
  static const String _lastRouteKey = 'last_visited_route';
  static const String _lastRouteArgsKey = 'last_route_args';
  
  /// Save the current route and its arguments
  static Future<void> saveRoute(String routeName, Map<String, dynamic>? arguments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRouteKey, routeName);
      
      // Save arguments as JSON-compatible strings
      if (arguments != null) {
        await prefs.setString('last_route_userId', arguments['userId']?.toString() ?? '');
        await prefs.setString('last_route_role', arguments['role']?.toString() ?? '');
        await prefs.setString('last_route_groupId', arguments['groupId']?.toString() ?? '');
        await prefs.setString('last_route_groupName', arguments['name']?.toString() ?? '');
      }
    } catch (e) {
      print('Error saving route: $e');
    }
  }
  
  /// Get the last visited route
  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastRouteKey);
    } catch (e) {
      print('Error getting last route: $e');
      return null;
    }
  }
  
  /// Get the last route arguments
  static Future<Map<String, dynamic>?> getLastRouteArguments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('last_route_userId');
      final role = prefs.getString('last_route_role');
      final groupId = prefs.getString('last_route_groupId');
      final groupName = prefs.getString('last_route_groupName');
      
      if (userId == null && role == null && groupId == null) {
        return null;
      }
      
      final args = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) args['userId'] = userId;
      if (role != null && role.isNotEmpty) args['role'] = role;
      if (groupId != null && groupId.isNotEmpty) args['groupId'] = groupId;
      if (groupName != null && groupName.isNotEmpty) args['name'] = groupName;
      
      return args.isEmpty ? null : args;
    } catch (e) {
      print('Error getting last route arguments: $e');
      return null;
    }
  }
  
  /// Clear the saved route (useful on logout or when user manually goes to home)
  static Future<void> clearRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRouteKey);
      await prefs.remove('last_route_userId');
      await prefs.remove('last_route_role');
      await prefs.remove('last_route_groupId');
      await prefs.remove('last_route_groupName');
    } catch (e) {
      print('Error clearing route: $e');
    }
  }
  
  /// Check if a route should be restored (not login or admin home)
  static bool shouldRestoreRoute(String? route) {
    if (route == null || route.isEmpty) return false;
    // Don't restore login or main admin page
    if (route == '/login' || route == '/admin' || route == '/forcePassword') return false;
    return true;
  }
}
