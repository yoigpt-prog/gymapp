import re

file_path = '/Users/apple/Desktop/gymguide_app/lib/pages/profile_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_methods = """  Widget _buildBulletPoint(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: const Color(0xFFFF0000)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String score, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 10, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          score,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF0000)),
        ),
      ],
    );
  }

  Widget _buildAITransformationPremiumCard() {
    final isDark = widget.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFFFF0000), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Transformation\\nSimulator',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'See your future body with AI',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildBulletPoint(Icons.verified_user_outlined, 'Realistic AI-powered preview', isDark),
                    _buildBulletPoint(Icons.compare_arrows_rounded, 'Before/after comparison slider', isDark),
                    _buildBulletPoint(Icons.shield_outlined, 'Private & secure processing', isDark),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/beforeafterimg.png',
                  width: 110,
                  height: 130,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 10, color: Color(0xFFFF0000)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Blurred preview · Unlock for HD results',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Try AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysiqueRatingPremiumCard() {
    final isDark = widget.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.accessibility_new_rounded, color: Color(0xFFFF0000), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate My\\nPhysique AI',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'AI analyzes your body\\nproportions',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildBulletPoint(Icons.verified_user_outlined, 'Detailed physique scoring', isDark),
                    _buildBulletPoint(Icons.auto_fix_high, 'Strengths & improvement areas', isDark),
                    _buildBulletPoint(Icons.fitness_center, 'Personalized muscle focus', isDark),
                    _buildBulletPoint(Icons.shield_outlined, 'Private & secure analysis', isDark),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OVERALL SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textColor)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Circle
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  value: 0.84,
                                  strokeWidth: 3.5,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('8.4', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                                  Text('/10', style: TextStyle(fontSize: 8, color: isDark ? Colors.white54 : Colors.black54)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Metrics List
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetric(Icons.balance, 'Symmetry', '8.7', isDark),
                                const SizedBox(height: 4),
                                _buildMetric(Icons.architecture, 'V-Taper', '8.2', isDark),
                                const SizedBox(height: 4),
                                _buildMetric(Icons.fitness_center, 'Muscularity', '8.6', isDark),
                                const SizedBox(height: 4),
                                _buildMetric(Icons.water_drop_outlined, 'Body Fat', '7.9', isDark),
                                const SizedBox(height: 4),
                                _buildMetric(Icons.straighten, 'Proportions', '8.3', isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.adjust, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Scan Body',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }"""

# Use regex to replace the entire block from _buildBulletPoint up to the end of _buildPhysiqueRatingPremiumCard
start_str = "  Widget _buildBulletPoint(IconData icon, String text, bool isDark) {"
end_str = "  Widget _buildMobileGoalsGrid() {"
start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_methods + "\n" + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched cards for responsiveness.")
else:
    print("Could not find the block to replace!")

