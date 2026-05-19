import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://wewztpamzhrzbbgyutyf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indld3p0cGFtemhyemJiZ3l1dHlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5MzAsImV4cCI6MjA3OTM4NzkzMH0.PfmIQFT6QFZFAc_sseoaSqFNKbE_F1dua3J4G1SKkws',
  );
  
  final client = Supabase.instance.client;
  
  // Sign in anonymously to test
  await client.auth.signInAnonymously();
  final user = client.auth.currentUser;
  print('User: ${user?.id}');
  
  try {
    await client.from('user_favorites').upsert({
      'user_id': user!.id,
      'exercise_name': 'Test Exercise',
    }, onConflict: 'user_id, exercise_name');
    print('Upsert SUCCESS');
  } catch (e) {
    print('Upsert ERROR: $e');
  }
  
  exit(0);
}
