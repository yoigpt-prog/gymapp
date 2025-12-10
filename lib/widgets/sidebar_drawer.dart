import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SidebarDrawer extends StatefulWidget {
  final int currentIndex;
  final Function(int) onItemSelected;
  final bool isDarkMode;
  final VoidCallback? onClose;

  const SidebarDrawer({
    Key? key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.isDarkMode,
    this.onClose,
  }) : super(key: key);

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Red theme to match GymGuide branding
    final backgroundColor = const Color(0xFFFF0000); // Bright Red
    final textColor = Colors.white;
    final selectedColor = Colors.white;
    final unselectedColor = Colors.white;
    final hoverColor = Colors.white.withOpacity(0.1);
    final selectedBgColor = Colors.white.withOpacity(0.15);

    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: ClipRect(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isExpanded ? 200 : 70,
          height: double.infinity,
          color: backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), // Top padding since menu button is gone

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      index: 0,
                      isSelected: widget.currentIndex == 0,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.calculate_outlined,
                      activeIcon: Icons.calculate,
                      label: 'BMI Calculator',
                      index: 6,
                      isSelected: widget.currentIndex == 6,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.local_fire_department_outlined,
                      activeIcon: Icons.local_fire_department,
                      label: 'Calorie Calculator',
                      index: 7,
                      isSelected: widget.currentIndex == 7,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.pie_chart_outline,
                      activeIcon: Icons.pie_chart,
                      label: 'Macro Calculator',
                      index: 8,
                      isSelected: widget.currentIndex == 8,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.monitor_weight_outlined,
                      activeIcon: Icons.monitor_weight,
                      label: 'Body Fat Estimator',
                      index: 9,
                      isSelected: widget.currentIndex == 9,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.fitness_center_outlined,
                      activeIcon: Icons.fitness_center,
                      label: '1RM Calculator',
                      index: 10,
                      isSelected: widget.currentIndex == 10,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),

                    const SizedBox(height: 24),

                    _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profile',
                      index: 4,
                      isSelected: widget.currentIndex == 4,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: 'Settings',
                      index: 5,
                      isSelected: widget.currentIndex == 5,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildNavItem(
                      icon: Icons.logout,
                      activeIcon: Icons.logout,
                      label: 'Login / Logout',
                      index: -1,
                      isSelected: false,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      hoverColor: hoverColor,
                      selectedBgColor: selectedBgColor,
                      onTapOverride: () {
                        // TODO: Implement Auth logic
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isSelected,
    required Color selectedColor,
    required Color unselectedColor,
    required Color hoverColor,
    required Color selectedBgColor,
    VoidCallback? onTapOverride,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapOverride ?? () => widget.onItemSelected(index),
        hoverColor: hoverColor,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: _isExpanded ? 16 : 8,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isExpanded
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? activeIcon : icon,
                        color: isSelected ? selectedColor : unselectedColor,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? selectedColor : unselectedColor,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? selectedColor : unselectedColor,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}
