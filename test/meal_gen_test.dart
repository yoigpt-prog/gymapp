import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('verify meal plan generation duration fix', () async {
    final client = SupabaseClient(
      'https://vniisqetezmbwovwbxnt.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuaWlzcWV0ZXptYndvdndieG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMDE5MDUsImV4cCI6MjA5Mzc3NzkwNX0.RZgIWpUqVRnT2fMmZ-S8U9YRR9H-PLmPN07cwcV5EQA',
    );

    // Sign in anonymously
    await client.auth.signInAnonymously();
    final user = client.auth.currentUser;
    expect(user, isNotNull);
    print('User ID: ${user!.id}');

    // 1. Upsert user_quiz_profile with 72 weeks (> 52)
    await client.from('user_quiz_profile').upsert({
      'user_id': user.id,
      'gender': 'male',
      'age': 28,
      'height_cm': 180,
      'weight_kg': 80,
      'goal': 'build_muscle',
      'activity_level': 'moderately_active',
      'diet_type': 'no_preference',
      'excluded_foods': [],
      'macro_preference': 'balanced',
      'timeline_weeks': 72, // > 52 weeks
    }, onConflict: 'user_id');
    print('Upserted user_quiz_profile with 72 weeks');

    // Verify DB row
    final quiz = await client
        .from('user_quiz_profile')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    print('DB user_quiz_profile: $quiz');
    expect(quiz!['timeline_weeks'], equals(72));

    // 2. Call generate_meal_plan_v2 RPC
    print('Calling generate_meal_plan_v2 RPC...');
    final response = await client.rpc(
      'generate_meal_plan_v2',
      params: {'p_user_id': user.id, 'p_force_regen': true},
    );
    print('RPC response: $response');

    // 3. Assert weeks returned = 72
    final weeks = response['weeks'];
    final rowsInserted = response['rows_inserted'];
    final status = response['status'];

    print('Status : $status');
    print('Weeks  : $weeks');
    print('Rows   : $rowsInserted');

    expect(status, equals('success'));
    expect(weeks, equals(72),
        reason: 'generate_meal_plan_v2 should respect timeline_weeks=72, not cap at 52');

    // 72 weeks * 7 days * 4 meal slots = 2016 rows
    expect(rowsInserted, equals(2016),
        reason: 'Expected 2016 meal rows for 72 weeks (72 * 7 * 4)');

    // 4. Spot-check week 53+ actually has rows in the DB
    final week53Rows = await client
        .from('user_meal_plan_v2')
        .select('id')
        .eq('user_id', user.id)
        .eq('week_number', 53)
        .limit(1);
    print('Week 53 rows sample: $week53Rows');
    expect(week53Rows, isNotEmpty,
        reason: 'Week 53 should have meal rows for a 72-week plan');
  });
}
