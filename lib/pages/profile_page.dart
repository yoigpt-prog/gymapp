import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io'; // Removed for web compatibility
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/red_header.dart';
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_service_page.dart';
import 'legal/disclaimer_page.dart';
import 'legal/subscription_terms_page.dart';
import 'legal/data_export_page.dart';
import 'legal/ai_transparency_page.dart';



class ProfilePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ProfilePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Profile image state
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();
  
  // User profile data
  String _userName = 'Guest User';
  String _userEmail = 'guest@gymguide.co';
  
  // Physical stats
  Map<String, dynamic> _userStats = {
    'height': '180 cm',
    'weight': '75 kg',
    'age': '28',
    'gender': 'Male',
    'goal': 'Build Muscle',
    'target_weight': '80 kg',
    'activity_level': 'Active',
    'diet': 'Balanced',
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    
    setState(() {
      _userName = prefs.getString('profile_name') ?? user?.userMetadata?['full_name'] ?? 'Guest User';
      _userEmail = user?.email ?? 'guest@gymguide.co';
      
      // Load stats from prefs if available
      _userStats['height'] = prefs.getString('profile_height') ?? '180 cm';
      _userStats['weight'] = prefs.getString('profile_weight') ?? '75 kg';
      _userStats['age'] = prefs.getString('profile_age') ?? '28';
      _userStats['gender'] = prefs.getString('profile_gender') ?? 'Male';
      _userStats['goal'] = prefs.getString('profile_goal') ?? 'Build Muscle';
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
        });
        // Could save to Supabase storage here
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
        _loadUserData(); // Update UI to show Guest
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final heightController = TextEditingController(text: _userStats['height']);
    final weightController = TextEditingController(text: _userStats['weight']);
    final ageController = TextEditingController(text: _userStats['age']);
    String selectedGender = _userStats['gender'];
    String selectedGoal = _userStats['goal'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (e.g., 180 cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (e.g., 75 kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Male', 'Female', 'Other'].map((g) => 
                    DropdownMenuItem(value: g, child: Text(g))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => selectedGender = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGoal,
                  decoration: const InputDecoration(
                    labelText: 'Fitness Goal',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Build Muscle',
                    'Lose Weight',
                    'Improve Fitness',
                    'Maintain Weight',
                    'Gain Strength',
                  ].map((g) => 
                    DropdownMenuItem(value: g, child: Text(g))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => selectedGoal = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Save to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('profile_name', nameController.text);
                await prefs.setString('profile_height', heightController.text);
                await prefs.setString('profile_weight', weightController.text);
                await prefs.setString('profile_age', ageController.text);
                await prefs.setString('profile_gender', selectedGender);
                await prefs.setString('profile_goal', selectedGoal);
                
                setState(() {
                  _userName = nameController.text;
                  _userStats['height'] = heightController.text;
                  _userStats['weight'] = weightController.text;
                  _userStats['age'] = ageController.text;
                  _userStats['gender'] = selectedGender;
                  _userStats['goal'] = selectedGoal;
                });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        
        if (isDesktop) {
          return _buildDesktopLayout();
        }
        
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          RedHeader(
            title: 'Profile',
            subtitle: 'Your Fitness Journey',
            onToggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: User Profile Card
                        SizedBox(
                          width: 350,
                          child: _buildUserProfileCard(),
                        ),
                        const SizedBox(width: 24),
                        
                        // Right Column: Stats & Goals Grid
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Physical Stats'),
                              const SizedBox(height: 16),
                              _buildStatsGrid(),
                              const SizedBox(height: 32),
                              _buildSectionTitle('Goals & Preferences'),
                              const SizedBox(height: 16),
                              _buildGoalsGrid(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // State for notifications toggle on mobile
  bool _notificationsEnabled = true;

  Widget _buildMobileLayout() {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          RedHeader(
            title: 'Profile',
            subtitle: 'Your Fitness Journey',
            onToggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfileCard(isMobile: true),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Physical Stats'),
                  const SizedBox(height: 16),
                  _buildStatsGrid(isMobile: true),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Goals & Preferences'),
                  const SizedBox(height: 16),
                  _buildMobileGoalsGrid(),
                  const SizedBox(height: 24),
                  // Notifications Toggle
                  _buildMobileSettingsCard(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                      activeColor: const Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dark Mode Toggle
                  _buildMobileSettingsCard(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: widget.isDarkMode ? 'Dark mode is on' : 'Light mode is on',
                    trailing: Switch(
                      value: widget.isDarkMode,
                      onChanged: (_) => widget.toggleTheme(),
                      activeColor: const Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Legal & Privacy Section
                  _buildMobileSectionHeader('Legal & Privacy'),
                  const SizedBox(height: 12),
                  _buildMobileLegalItem(
                    icon: Icons.description_outlined,
                    title: 'EULA',
                    subtitle: 'End User License Agreement',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionTermsPage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.article_outlined,
                    title: 'Terms of Service',
                    subtitle: 'Terms and conditions',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsOfServicePage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.info_outline,
                    title: 'Disclaimer',
                    subtitle: 'Important information',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DisclaimerPage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.credit_card_outlined,
                    title: 'Subscription Terms',
                    subtitle: 'Billing and subscription info',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionTermsPage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.download_outlined,
                    title: 'Data & Export',
                    subtitle: 'Download your personal data',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DataExportPage())),
                  ),
                  const SizedBox(height: 8),
                  _buildMobileLegalItem(
                    icon: Icons.psychology_outlined,
                    title: 'AI Transparency',
                    subtitle: 'How AI is used in this app',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AITransparencyPage())),
                  ),
                  const SizedBox(height: 24),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF0000),
                        side: const BorderSide(color: Color(0xFFFF0000)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileGoalsGrid() {
    // Only show Goal card on mobile (excluding Target Weight, Activity, Diet Type)
    // Full width for single Goal card
    return _buildStatCard('Goal', _userStats['goal'], Icons.flag_outlined, true, width: MediaQuery.of(context).size.width - 32);
  }

  Widget _buildMobileSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: widget.isDarkMode ? Colors.white54 : Colors.black54,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMobileSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF0000),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildMobileLegalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF0000),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard({bool isMobile = false}) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    // Determine border color: black for mobile, subtle for desktop
    final borderColor = isMobile ? Colors.black : (widget.isDarkMode ? Colors.white12 : Colors.black12);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(
          color: isMobile ? (widget.isDarkMode ? Colors.white : Colors.black) : borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Profile Image or Initial
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF0000).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFFF0000), width: 2),
                    image: _profileImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_profileImageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImageBytes == null
                      ? Center(
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'G',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF0000),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              // Camera button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _userName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 16,
              color: subTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildProfileStatRow('Member Since', 'Dec 2024', textColor),
          const SizedBox(height: 16),
          _buildProfileStatRow('Plan Status', 'Free Trial', const Color(0xFFFF0000)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showEditProfileDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _signOut,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text('Log Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatRow(String label, String value, Color valueColor) {
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: widget.isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildStatsGrid({bool isMobile = false}) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Height', _userStats['height'], Icons.height, isMobile),
        _buildStatCard('Weight', _userStats['weight'], Icons.monitor_weight_outlined, isMobile),
        _buildStatCard('Age', _userStats['age'], Icons.cake_outlined, isMobile),
        _buildStatCard('Gender', _userStats['gender'], Icons.person_outline, isMobile),
      ],
    );
  }

  Widget _buildGoalsGrid({bool isMobile = false}) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Goal', _userStats['goal'], Icons.flag_outlined, isMobile, width: isMobile ? null : 300),
        _buildStatCard('Target Weight', _userStats['target_weight'], Icons.track_changes, isMobile),
        _buildStatCard('Activity', _userStats['activity_level'], Icons.directions_run, isMobile),
        _buildStatCard('Diet Type', _userStats['diet'], Icons.restaurant_menu, isMobile),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, bool isMobile, {double? width}) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    // Calculate width for grid items
    // On desktop, we want 2 items per row roughly, or auto-flow
    // Default width for stat cards
    final cardWidth = width ?? (isMobile ? (MediaQuery.of(context).size.width - 48) / 2 : 200.0);

    // Mobile layout: more compact, reduced vertical spacing for rectangular look
    if (isMobile) {
      return Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF0000),
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    // Desktop layout: original design
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF0000),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
