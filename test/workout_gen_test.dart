import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('verify workout generation duration fix', () async {
    final client = SupabaseClient(
      'https://vniisqetezmbwovwbxnt.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuaWlzcWV0ZXptYndvdndieG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMDE5MDUsImV4cCI6MjA5Mzc3NzkwNX0.RZgIWpUqVRnT2fMmZ-S8U9YRR9H-PLmPN07cwcV5EQA',
    );
    
    // Sign in anonymously to test
    await client.auth.signInAnonymously();
    final user = client.auth.currentUser;
    expect(user, isNotNull);
    print('User ID: ${user!.id}');
    
    // 1. Upsert user preferences
    await client.from('user_preferences').upsert({
      'user_id': user.id,
      'goal': 'build_muscle',
      'gender': 'male',
      'training_location': 'gym',
      'training_days': 4,
      'duration_weeks': 72, // > 52 weeks
      'experience_level': 'intermediate',
      'session_duration': '60 min',
    }, onConflict: 'user_id');
    print('Upserted user_preferences');

    // 2. Upsert user_quiz_profile
    await client.from('user_quiz_profile').upsert({
      'user_id': user.id,
      'gender': 'male',
      'goal': 'build_muscle',
      'timeline_weeks': 72, // > 52 weeks
    }, onConflict: 'user_id');
    print('Upserted user_quiz_profile');

    // Query both
    final prefs = await client.from('user_preferences').select().eq('user_id', user.id).maybeSingle();
    final quiz = await client.from('user_quiz_profile').select().eq('user_id', user.id).maybeSingle();
    print('DB user_preferences: $prefs');
    print('DB user_quiz_profile: $quiz');

    // 3. Call generate_user_workout_plan RPC
    print('Calling generate_user_workout_plan RPC...');
    final response = await client.rpc(
      'generate_user_workout_plan',
      params: {'p_user_id': user.id},
    );
    print('RPC response: $response');
  });
}
