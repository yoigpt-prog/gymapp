import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ExerciseSeoData {
  final String? overview;
  final String? benefits;
  final String? commonMistakes;
  final String? proTips;
  final String? muscleAnatomy;
  final String? bestWorkoutSplits;
  final String? exerciseVariations;
  final String? beginnerTips;
  final String? advancedTips;
  final String? breathingTechnique;
  final String? recommendedFrequency;
  final String? whoShouldAvoid;
  
  final String? stabilizerMuscles;
  final String? movementPattern;
  final String? forceType;
  final String? mechanicsType;
  
  final String? faq1Question;
  final String? faq1Answer;
  final String? faq2Question;
  final String? faq2Answer;
  final String? faq3Question;
  final String? faq3Answer;
  final String? faq4Question;
  final String? faq4Answer;
  final String? faq5Question;
  final String? faq5Answer;
  
  final String? seoTitle;
  final String? seoDescription;
  
  final String? equipmentType;
  final String? workoutCategory;
  final int? variationCount;
  final String? estimatedCaloriesBurned;

  ExerciseSeoData({
    this.overview, this.benefits, this.commonMistakes, this.proTips,
    this.muscleAnatomy, this.bestWorkoutSplits, this.exerciseVariations,
    this.beginnerTips, this.advancedTips, this.breathingTechnique,
    this.recommendedFrequency, this.whoShouldAvoid,
    this.stabilizerMuscles, this.movementPattern, this.forceType, this.mechanicsType,
    this.faq1Question, this.faq1Answer, this.faq2Question, this.faq2Answer,
    this.faq3Question, this.faq3Answer, this.faq4Question, this.faq4Answer,
    this.faq5Question, this.faq5Answer,
    this.seoTitle, this.seoDescription,
    this.equipmentType, this.workoutCategory, this.variationCount, this.estimatedCaloriesBurned
  });

  factory ExerciseSeoData.fromJson(Map<String, dynamic> json) {
    return ExerciseSeoData(
      overview: json['overview'],
      benefits: json['benefits'],
      commonMistakes: json['common_mistakes'],
      proTips: json['pro_tips'],
      muscleAnatomy: json['muscle_anatomy'],
      bestWorkoutSplits: json['best_workout_splits'],
      exerciseVariations: json['exercise_variations'],
      beginnerTips: json['beginner_tips'],
      advancedTips: json['advanced_tips'],
      breathingTechnique: json['breathing_technique'],
      recommendedFrequency: json['recommended_frequency'],
      whoShouldAvoid: json['who_should_avoid'],
      stabilizerMuscles: json['stabilizer_muscles'],
      movementPattern: json['movement_pattern'],
      forceType: json['force_type'],
      mechanicsType: json['mechanics_type'],
      faq1Question: json['faq_1_question'],
      faq1Answer: json['faq_1_answer'],
      faq2Question: json['faq_2_question'],
      faq2Answer: json['faq_2_answer'],
      faq3Question: json['faq_3_question'],
      faq3Answer: json['faq_3_answer'],
      faq4Question: json['faq_4_question'],
      faq4Answer: json['faq_4_answer'],
      faq5Question: json['faq_5_question'],
      faq5Answer: json['faq_5_answer'],
      seoTitle: json['seo_title'],
      seoDescription: json['seo_description'],
      equipmentType: json['equipment_type'],
      workoutCategory: json['workout_category'],
      variationCount: json['variation_count'] is int ? json['variation_count'] : int.tryParse(json['variation_count']?.toString() ?? ''),
      estimatedCaloriesBurned: json['estimated_calories_burned']?.toString(),
    );
  }
}

class SeoCacheService {
  static final Map<String, ExerciseSeoData> _cache = {};

  static Future<ExerciseSeoData?> fetchSeoData(String exerciseId) async {
    if (!kIsWeb) return null; // Ensure Native apps NEVER download this
    
    if (_cache.containsKey(exerciseId)) {
      return _cache[exerciseId];
    }

    try {
      String targetId = exerciseId;
      
      // If the exerciseId passed is actually the name (e.g. "45 degree Side Bend") 
      // because the RPC didn't return the ID, fetch the true ID first.
      if (!RegExp(r'^\d+$').hasMatch(exerciseId)) {
        final exResponse = await Supabase.instance.client
            .from('exercises')
            .select('id')
            .eq('exercise_name', exerciseId)
            .limit(1);
        if (exResponse.isNotEmpty && exResponse[0]['id'] != null) {
          targetId = exResponse[0]['id'].toString();
        }
      }

      final response = await Supabase.instance.client
          .from('exercise_seo')
          .select()
          .eq('exercise_id', targetId)
          .maybeSingle();

      if (response != null) {
        final data = ExerciseSeoData.fromJson(response);
        _cache[exerciseId] = data;
        return data;
      }
    } catch (e) {
      debugPrint("Error fetching SEO data: $e");
    }
    
    return null;
  }
  
  static Future<List<Map<String, dynamic>>> fetchRelatedExercises(
      String currentId, String targetMuscle, String equipment) async {
    if (!kIsWeb) return [];
    
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id, exercise_name, exercise_slug, urls')
          .neq('id', currentId)
          .or('target_muscle.ilike.%$targetMuscle%,equipment.ilike.%$equipment%')
          .limit(4);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching related exercises: $e");
    }
    return [];
  }
}
