import 'package:flutter/foundation.dart';
import 'dynamic_firebase_options.dart';

/// SchoolContext: Centralized service to manage current school's ID
/// 
/// This service provides the current school's ID throughout the app,
/// ensuring all database operations are isolated by school.
/// 
/// Usage:
///   - Initialize once at app startup: await SchoolContext.initialize()
///   - Access anywhere: SchoolContext.currentSchoolId
///   - Check if initialized: SchoolContext.isInitialized
class SchoolContext {
  static String? _currentSchoolId;
  static String? _currentSchoolName;
  static bool _isInitialized = false;
  
  /// Initialize the school context by loading the school key from storage
  /// This should be called once at app startup in main.dart
  static Future<void> initialize() async {
    try {
      _currentSchoolId = await DynamicFirebaseOptions.getSchoolKey();
      _currentSchoolName = await DynamicFirebaseOptions.getSchoolName();
      _isInitialized = true;
      
      if (_currentSchoolId != null) {
        debugPrint('✅ SchoolContext initialized: $_currentSchoolId ($_currentSchoolName)');
      } else {
        debugPrint('⚠️ SchoolContext initialized but no school key found');
      }
    } catch (e) {
      debugPrint('❌ Error initializing SchoolContext: $e');
      _isInitialized = false;
    }
  }
  
  /// Get the current school ID
  /// Throws an exception if not initialized or no school is set
  static String get currentSchoolId {
    if (!_isInitialized) {
      throw Exception('SchoolContext not initialized. Call SchoolContext.initialize() first.');
    }
    
    if (_currentSchoolId == null || _currentSchoolId!.isEmpty) {
      throw Exception('No school selected. Please enter a school key first.');
    }
    
    return _currentSchoolId!;
  }
  
  /// Get the current school ID or null if not set
  /// Does not throw exception - safe to use for conditional logic
  static String? get currentSchoolIdOrNull {
    return _currentSchoolId;
  }
  
  /// Get the current school name
  static String? get currentSchoolName {
    return _currentSchoolName;
  }
  
  /// Check if SchoolContext has been initialized
  static bool get isInitialized {
    return _isInitialized;
  }
  
  /// Check if a school is currently selected
  static bool get hasSchool {
    return _currentSchoolId != null && _currentSchoolId!.isNotEmpty;
  }
  
  /// Update the school context (call when user selects a new school)
  static Future<void> setSchool(String schoolId, String schoolName) async {
    try {
      await DynamicFirebaseOptions.setSchoolKey(schoolId, schoolName);
      _currentSchoolId = schoolId;
      _currentSchoolName = schoolName;
      _isInitialized = true;
      
      debugPrint('✅ SchoolContext updated: $schoolId ($schoolName)');
    } catch (e) {
      debugPrint('❌ Error updating SchoolContext: $e');
      rethrow;
    }
  }
  
  /// Clear the school context (call on logout or school switch)
  static Future<void> clear() async {
    _currentSchoolId = null;
    _currentSchoolName = null;
    _isInitialized = false;
    
    debugPrint('🔄 SchoolContext cleared');
  }
  
  /// Refresh the school context from storage
  static Future<void> refresh() async {
    await initialize();
  }
}
