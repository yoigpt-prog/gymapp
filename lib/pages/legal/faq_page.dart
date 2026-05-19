import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/legal_page_layout.dart';
import '../../data/faq_data.dart';
import 'package:url_launcher/url_launcher.dart';

class FaqPage extends StatefulWidget {
  final VoidCallback? toggleTheme;
  const FaqPage({super.key, this.toggleTheme});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "General",
    "Subscription",
    "Workouts",
    "Nutrition",
    "Calculators",
    "Account & Privacy"
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF0000);
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    List<FaqItem> filteredFaqs = faqData.where((faq) {
      final matchesSearch = faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == "All" || faq.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return LegalPageLayout(
      onToggleTheme: widget.toggleTheme,
      title: 'Frequently Asked Questions',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          _buildHero(isDarkMode, primaryColor),
          const SizedBox(height: 40),

          // Search Bar
          _buildSearchBar(isDarkMode, primaryColor),
          const SizedBox(height: 32),

          // Categories
          _buildCategories(isDarkMode, primaryColor),
          const SizedBox(height: 32),

          // FAQ List
          if (filteredFaqs.isEmpty)
            _buildEmptyState(isDarkMode)
          else
            ...filteredFaqs.map((faq) => _buildFaqAccordion(faq, isDarkMode, primaryColor, cardColor)).toList(),

          const SizedBox(height: 60),

          // Support Section
          _buildSupportSection(isDarkMode, primaryColor, cardColor),
          const SizedBox(height: 60),

          // SEO Section
          _buildSeoSection(isDarkMode),
          const SizedBox(height: 60),

          // Internal Links
          _buildInternalLinks(isDarkMode, primaryColor, cardColor),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
            ? [primaryColor.withOpacity(0.2), Colors.transparent]
            : [primaryColor.withOpacity(0.05), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_center_outlined, size: 48, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            "How can we help you?",
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Everything you need to know about GymGuide, workouts, nutrition, subscriptions, and fitness tools.",
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: isDarkMode ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: "Search a question...",
          hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(Icons.search, color: primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCategories(bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: primaryColor,
              labelStyle: GoogleFonts.outfit(
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqAccordion(FaqItem faq, bool isDarkMode, Color primaryColor, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        iconColor: primaryColor,
        collapsedIconColor: isDarkMode ? Colors.white54 : Colors.black54,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        expandedAlignment: Alignment.topLeft,
        children: [
          Text(
            faq.answer,
            style: GoogleFonts.outfit(
              fontSize: 15,
              height: 1.6,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: isDarkMode ? Colors.white24 : Colors.black12),
            const SizedBox(height: 16),
            Text(
              "No results found",
              style: GoogleFonts.outfit(fontSize: 18, color: isDarkMode ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection(bool isDarkMode, Color primaryColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            "Still need help?",
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Our support team is here to help you 24/7.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: isDarkMode ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSupportCard("Email Support", "contact@gymguide.co", Icons.email_outlined, isDarkMode, primaryColor, cardColor),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Contact Support", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(String title, String val, IconData icon, bool isDarkMode, Color primaryColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(val, style: GoogleFonts.outfit(color: primaryColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSeoSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Master Your Fitness Journey",
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          "GymGuide is designed to bridge the gap between high-level fitness knowledge and your daily routine. Our AI-driven workout tools and health calculators are built on the latest sports science and nutritional research, providing you with a solid foundation for sustainable growth.\n\nWhether you're looking for a personalized AI workout planner, detailed nutrition tracking, or accurate body composition estimates, our platform provides everything you need in one place. We believe that fitness should be accessible, data-driven, and intuitive.",
          style: GoogleFonts.outfit(fontSize: 16, height: 1.7, color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
      ],
    );
  }

  Widget _buildInternalLinks(bool isDarkMode, Color primaryColor, Color cardColor) {
    final links = [
      {'name': 'BMI Calculator', 'route': '/calculators/bmi'},
      {'name': 'Macro Calculator', 'route': '/calculators/macro'},
      {'name': 'Workout Planner', 'route': '/workout'},
      {'name': 'Meal Plans', 'route': '/meal-plan'},
      {'name': 'Fitness Blog', 'route': '/Blog'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Quick Links", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: links.map((link) {
            return InkWell(
              onTap: () => Navigator.pushNamed(context, link['route']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: Text(
                  link['name']!,
                  style: GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
