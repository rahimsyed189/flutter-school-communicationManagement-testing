import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AIFormGenerator {
  static Future<String?> _getApiKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('gemini_config')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final enabled = data['enabled'] as bool? ?? false;
        if (enabled) {
          return data['apiKey'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('Error loading Gemini API key: $e');
      return null;
    }
  }

  /// Discovers available Gemini models by calling the ListModels API
  static Future<void> discoverAvailableModels() async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('❌ No API key configured');
      return;
    }

    print('🔍 Discovering available Gemini models...');

    // Try v1 API
    try {
      final urlV1 = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$apiKey'
      );
      print('📡 Calling v1 ListModels API...');
      final responseV1 = await http.get(urlV1);
      print('📥 v1 Response status: ${responseV1.statusCode}');
      
      if (responseV1.statusCode == 200) {
        final data = json.decode(responseV1.body);
        print('✅ v1 API Models:');
        if (data['models'] != null) {
          for (var model in data['models']) {
            final name = model['name'];
            final supportedMethods = model['supportedGenerationMethods'] ?? [];
            print('  - $name');
            print('    Methods: $supportedMethods');
          }
        }
      } else {
        print('❌ v1 API Error: ${responseV1.body}');
      }
    } catch (e) {
      print('❌ v1 API Exception: $e');
    }

    print('');

    // Try v1beta API
    try {
      final urlV1Beta = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'
      );
      print('📡 Calling v1beta ListModels API...');
      final responseV1Beta = await http.get(urlV1Beta);
      print('📥 v1beta Response status: ${responseV1Beta.statusCode}');
      
      if (responseV1Beta.statusCode == 200) {
        final data = json.decode(responseV1Beta.body);
        print('✅ v1beta API Models:');
        if (data['models'] != null) {
          for (var model in data['models']) {
            final name = model['name'];
            final supportedMethods = model['supportedGenerationMethods'] ?? [];
            print('  - $name');
            print('    Methods: $supportedMethods');
          }
        }
      } else {
        print('❌ v1beta API Error: ${responseV1Beta.body}');
      }
    } catch (e) {
      print('❌ v1beta API Exception: $e');
    }
  }

  /// Generate form fields from natural language description
  /// Returns a list of field configurations or null if failed
  static Future<List<Map<String, dynamic>>?> generateFields(String prompt) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      print('Gemini API key not configured');
      return null;
    }

    try {
      // Use Gemini 2.5 Flash - the newest, fastest model available in v1 API
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey'
      );

      final systemPrompt = '''
Generate form fields as JSON array ONLY. No markdown, no explanation.

Required properties per field:
- name (camelCase), type (text/number/email/phone/date/dropdown/textarea/checkbox), label, required (bool)
- group (section name), groupColor (blue/purple/green/orange/red/teal/pink), groupIcon (person/phone/school/medical/location/calendar/info/star), order (number)
- options (array, for dropdown only), placeholder (optional)

Grouping guidelines:
- Personal info → blue, person icon
- Contact details → green, phone/location icons  
- Academic → purple, school icon
- Medical → red, medical icon
- Emergency → orange, star icon

Examples:
"student name and DOB" → [{"name":"studentName","type":"text","label":"Student Name","required":true,"group":"Personal Information","groupColor":"blue","groupIcon":"person","order":1},{"name":"dateOfBirth","type":"date","label":"Date of Birth","required":true,"group":"Personal Information","groupColor":"blue","groupIcon":"person","order":2}]

"blood group field" → [{"name":"bloodGroup","type":"dropdown","label":"Blood Group","required":true,"options":["A+","A-","B+","B-","O+","O-","AB+","AB-"],"group":"Medical Information","groupColor":"red","groupIcon":"medical","order":1}]

User request:
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': '$systemPrompt\n$prompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 4096,
        }
      };

      print('🚀 Sending request to Gemini API...');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        final errorCode = errorBody['error']?['code'] ?? response.statusCode;
        
        print('❌ API Error: ${response.body}');
        
        // Return detailed error message based on status code
        if (errorCode == 429) {
          throw 'Rate limit exceeded. Please wait a moment and try again.';
        } else if (errorCode == 403) {
          throw 'API key quota exceeded or invalid. Please check your Gemini API configuration.';
        } else if (errorCode == 400) {
          throw 'Invalid request. Your prompt may be too long or contain unsupported content.';
        } else if (errorCode == 401) {
          throw 'API key is invalid or expired. Please update your Gemini API key in settings.';
        } else if (errorCode == 500 || errorCode == 503) {
          throw 'Gemini service temporarily unavailable. Please try again in a few moments.';
        } else {
          throw 'API Error ($errorCode): $errorMessage';
        }
      }

      final responseData = json.decode(response.body);
      
      // Check for safety/content filtering blocks
      if (responseData['promptFeedback'] != null) {
        final blockReason = responseData['promptFeedback']['blockReason'];
        if (blockReason != null) {
          throw 'Your request was blocked: $blockReason. Please rephrase your prompt.';
        }
      }
      
      final candidates = responseData['candidates'] as List?;
      
      if (candidates == null || candidates.isEmpty) {
        print('❌ No candidates in response');
        throw 'AI could not generate fields. The prompt may be unclear or too complex. Please try a simpler request.';
      }

      // Check if content was filtered
      final finishReason = candidates[0]['finishReason'];
      if (finishReason == 'SAFETY') {
        throw 'Content was blocked by safety filters. Please rephrase your request.';
      } else if (finishReason == 'MAX_TOKENS') {
        throw 'Response too long. Try requesting 3-5 fields at a time instead of creating a complete form in one go.';
      } else if (finishReason == 'RECITATION') {
        throw 'AI detected potential copyright issues. Please rephrase your request.';
      }

      final content = candidates[0]['content'];
      if (content == null) {
        throw 'AI returned empty response. Please try rephrasing your request.';
      }
      
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw 'AI response format invalid. Please try again.';
      }
      
      final text = parts[0]['text'] as String;
      
      print('✅ Gemini API Response received');
      print('📝 Raw response: $text');

      // Clean up the response - remove markdown code blocks if present
      String jsonText = text.trim();
      
      // Remove various markdown code block formats
      jsonText = jsonText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .replaceAll(RegExp(r'`'), '')
          .trim();
      
      // Try to extract JSON array if there's extra text
      final arrayMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonText);
      if (arrayMatch != null) {
        jsonText = arrayMatch.group(0)!;
      }
      
      print('🔧 Cleaned JSON: $jsonText');
      
      // Validate that we have actual JSON
      if (jsonText.isEmpty || (!jsonText.startsWith('[') && !jsonText.startsWith('{'))) {
        throw 'AI returned invalid format. Expected field definitions but got text response.';
      }
      
      // Parse JSON
      try {
        final dynamic parsed = json.decode(jsonText);
        if (parsed is List) {
          if (parsed.isEmpty) {
            throw 'AI generated no fields. Please provide a more detailed request.';
          }
          
          final fields = List<Map<String, dynamic>>.from(
            parsed.map((item) => Map<String, dynamic>.from(item as Map))
          );
          
          // Validate each field has required properties
          for (var i = 0; i < fields.length; i++) {
            final field = fields[i];
            if (field['name'] == null || field['type'] == null || field['label'] == null) {
              throw 'Field ${i + 1} is missing required properties. Please try again.';
            }
          }
          
          print('✅ Successfully parsed ${fields.length} fields');
          return fields;
        } else {
          throw 'AI returned wrong format (expected array of fields).';
        }
      } catch (e) {
        if (e is String) {
          rethrow; // Re-throw our custom error messages
        }
        print('❌ Failed to parse JSON: $e');
        print('📄 Attempted to parse: $jsonText');
        throw 'AI response could not be understood. Please try a simpler request.';
      }
    } catch (e) {
      if (e is String) {
        rethrow; // Re-throw our formatted error messages
      }
      print('Error generating fields with Gemini: $e');
      throw 'Unexpected error: ${e.toString()}';
    }
  }

  /// Save generated fields to Firestore form config
  static Future<bool> addFieldsToForm({
    required String formType, // 'students' or 'staff'
    required List<Map<String, dynamic>> fields,
  }) async {
    try {
      final docId = '${formType}_form_config';
      final docRef = FirebaseFirestore.instance
          .collection('app_config')
          .doc(docId);

      // Get existing config
      final doc = await docRef.get();
      List<dynamic> existingFields = [];
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        existingFields = data['fields'] as List<dynamic>? ?? [];
      }

      // Add new fields
      existingFields.addAll(fields);

      // Save back to Firestore
      await docRef.set({
        'fields': existingFields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error saving fields to Firestore: $e');
      return false;
    }
  }

  /// Get current form configuration
  static Future<List<Map<String, dynamic>>> getFormConfig(String formType) async {
    try {
      final docId = '${formType}_form_config';
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final fields = data['fields'] as List<dynamic>? ?? [];
        return List<Map<String, dynamic>>.from(
          fields.map((item) => Map<String, dynamic>.from(item as Map))
        );
      }
      return [];
    } catch (e) {
      print('Error loading form config: $e');
      return [];
    }
  }

  /// Remove a field from form configuration
  static Future<bool> removeField({
    required String formType,
    required String fieldName,
  }) async {
    try {
      final docId = '${formType}_form_config';
      final docRef = FirebaseFirestore.instance
          .collection('app_config')
          .doc(docId);

      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> fields = data['fields'] as List<dynamic>? ?? [];
        
        // Remove field with matching name
        fields.removeWhere((field) => 
          (field as Map<String, dynamic>)['name'] == fieldName
        );

        await docRef.set({
          'fields': fields,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return true;
      }
      return false;
    } catch (e) {
      print('Error removing field: $e');
      return false;
    }
  }

  /// Clear all fields from form configuration
  static Future<bool> clearFormConfig(String formType) async {
    try {
      final docId = '${formType}_form_config';
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc(docId)
          .set({
        'fields': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error clearing form config: $e');
      return false;
    }
  }
}
