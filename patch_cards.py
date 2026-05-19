import re

file_path = '/Users/apple/Desktop/gymguide_app/lib/pages/profile_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the calls
old_calls = """                      // ── AI Feature Cards ──────────────────────────────────
                      _buildAIFeatureCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FF7), Color(0xFFFF0080)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.auto_awesome_rounded,
                        label: 'COMING SOON',
                        title: 'AI Transformation Simulator',
                        subtitle: 'See your future body with AI',
                        buttonLabel: 'Transform',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildAIFeatureCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0066FF), Color(0xFF00C6FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.accessibility_new_rounded,
                        label: 'COMING SOON',
                        title: 'Rate My Physique AI',
                        subtitle: 'AI analyzes your body proportions',
                        buttonLabel: 'Analyze',
                        onTap: () {},
                      ),
                      // ──────────────────────────────────────────────────────"""

new_calls = """                      // ── AI Premium Feature Cards ────────────────────────
                      _buildAITransformationPremiumCard(),
                      const SizedBox(height: 16),
                      _buildPhysiqueRatingPremiumCard(),
                      // ──────────────────────────────────────────────────────"""

content = content.replace(old_calls, new_calls)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

