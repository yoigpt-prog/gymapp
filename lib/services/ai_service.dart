import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  // TODO: Replace with your actual API key or use .env
  // For security, it's best to use a backend proxy, but for this demo we'll call directly.
  static const String _apiKey = 'YOUR_OPENAI_API_KEY_HERE'; 
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, dynamic>> generatePersonalizedPlan(Map<String, dynamic> userProfile) async {
    try {
      final prompt = _buildPrompt(userProfile);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert fitness trainer and nutritionist. Generate a personalized workout and meal plan based on the user profile. Return ONLY valid JSON.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return jsonDecode(content);
      } else {
        throw Exception('Failed to generate plan: ${response.body}');
      }
    } catch (e) {
      print('Error generating plan: $e');
      // Return a mock plan or rethrow depending on error handling strategy
      rethrow;
    }
  }

  String _buildPrompt(Map<String, dynamic> profile) {
    return '''
    Generate a 7-day workout plan and a 1-day sample meal plan for a user with the following profile:
    
    - Name: ${profile['name']}
    - Age: ${profile['age']}
    - Gender: ${profile['gender']}
    - Goal: ${profile['goal']}
    - Experience Level: ${profile['experience']}
    - Equipment: ${profile['equipment']}
    - Days per week: ${profile['daysPerWeek']}
    - Dietary Preference: ${profile['diet']}
    - Target Weight: ${profile['targetWeight']} ${profile['targetWeightUnit']}
    
    The output JSON must strictly follow this schema:
    {
      "workout_plan": [
        {
          "day": "Monday",
          "focus": "Chest & Triceps",
          "exercises": [
            {
              "name": "Push-ups",
              "sets": "3",
              "reps": "12-15"
            }
          ]
        }
        // ... for 7 days (use "Rest" for rest days)
      ],
      "meal_plan": {
        "calories": 2500,
        "protein": "180g",
        "carbs": "250g",
        "fats": "80g",
        "meals": [
          {
            "name": "Breakfast",
            "description": "Oatmeal with protein powder and berries",
            "calories": 500
          },
          {
            "name": "Lunch",
            "description": "Grilled chicken breast with quinoa and broccoli",
            "calories": 700
          },
          {
            "name": "Dinner",
            "description": "Salmon with sweet potato and asparagus",
            "calories": 700
          },
          {
            "name": "Snack",
            "description": "Greek yogurt with almonds",
            "calories": 300
          }
        ]
      }
    }
    ''';
  }
}
