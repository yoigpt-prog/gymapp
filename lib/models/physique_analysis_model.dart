class PhysiqueAnalysis {
  final double overallScore;
  final String scoreLabel;
  final PhysiqueBreakdown breakdown;
  final List<String> strengths;
  final List<String> focusAreas;
  final String bodyType;
  final String aiSummary;

  const PhysiqueAnalysis({
    required this.overallScore,
    required this.scoreLabel,
    required this.breakdown,
    required this.strengths,
    required this.focusAreas,
    required this.bodyType,
    required this.aiSummary,
  });

  factory PhysiqueAnalysis.fromJson(Map<String, dynamic> json) {
    return PhysiqueAnalysis(
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 5.0,
      scoreLabel: (json['score_label'] as String?) ?? 'Building Phase',
      breakdown: PhysiqueBreakdown.fromJson(
          (json['physique_breakdown'] as Map<String, dynamic>?) ?? {}),
      strengths: List<String>.from((json['strengths'] as List?) ?? []),
      focusAreas: List<String>.from((json['focus_areas'] as List?) ?? []),
      bodyType: (json['body_type'] as String?) ?? 'Athletic',
      aiSummary: (json['ai_summary'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'score_label': scoreLabel,
        'physique_breakdown': breakdown.toJson(),
        'strengths': strengths,
        'focus_areas': focusAreas,
        'body_type': bodyType,
        'ai_summary': aiSummary,
      };
}

class PhysiqueBreakdown {
  final double symmetry;
  final double vTaper;
  final double muscularity;
  final double bodyFat;
  final double proportions;
  final double shoulderWidth;
  final double chestDevelopment;
  final double armDevelopment;
  final double legBalance;

  const PhysiqueBreakdown({
    required this.symmetry,
    required this.vTaper,
    required this.muscularity,
    required this.bodyFat,
    required this.proportions,
    required this.shoulderWidth,
    required this.chestDevelopment,
    required this.armDevelopment,
    required this.legBalance,
  });

  factory PhysiqueBreakdown.fromJson(Map<String, dynamic> json) {
    double get(String key) => (json[key] as num?)?.toDouble() ?? 5.0;
    return PhysiqueBreakdown(
      symmetry: get('symmetry'),
      vTaper: get('v_taper'),
      muscularity: get('muscularity'),
      bodyFat: get('body_fat'),
      proportions: get('proportions'),
      shoulderWidth: get('shoulder_width'),
      chestDevelopment: get('chest_development'),
      armDevelopment: get('arm_development'),
      legBalance: get('leg_balance'),
    );
  }

  Map<String, dynamic> toJson() => {
        'symmetry': symmetry,
        'v_taper': vTaper,
        'muscularity': muscularity,
        'body_fat': bodyFat,
        'proportions': proportions,
        'shoulder_width': shoulderWidth,
        'chest_development': chestDevelopment,
        'arm_development': armDevelopment,
        'leg_balance': legBalance,
      };

  /// All entries for rendering — primary metrics first, secondary after divider.
  List<MapEntry<String, double>> primaryEntries() => [
        MapEntry('Symmetry', symmetry),
        MapEntry('V-Taper', vTaper),
        MapEntry('Muscularity', muscularity),
        MapEntry('Body Fat', bodyFat),
        MapEntry('Proportions', proportions),
      ];

  List<MapEntry<String, double>> secondaryEntries() => [
        MapEntry('Shoulder Width', shoulderWidth),
        MapEntry('Chest', chestDevelopment),
        MapEntry('Arms', armDevelopment),
        MapEntry('Leg Balance', legBalance),
      ];
}
