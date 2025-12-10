import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable red header widget used across all pages for consistency
class RedHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? rightWidget;
  final double? height;
  final bool showBack;
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;
  final ValueChanged<String>? onSearch;
  final TextEditingController? searchController;

  const RedHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.rightWidget,
    this.height,
    this.showBack = false,
    this.onToggleTheme,
    this.isDarkMode,
    this.onSearch,
    this.searchController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          isWeb ? 12 : 16,
          isWeb ? 8 : 12,
          isWeb ? 12 : 16,
          isWeb ? 8 : 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
        ),
        child: isWeb ? _buildWebHeader(context) : _buildMobileHeader(context),
      ),
    );
  }

  // Web layout with logo, search, and settings
  Widget _buildWebHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        SvgPicture.asset(
          'assets/svg/logo/gymguideicon.svg',
          height: 35,
        ),
        const SizedBox(width: 20),
        
        // Spacer
        const Spacer(),
        
        // Search bar
        Container(
          width: 280,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Dark mode toggle
        InkWell(
          onTap: onToggleTheme,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isDarkMode == true ? Icons.dark_mode : Icons.wb_sunny_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

      ],
    );
  }

  // Mobile layout (original design)
  Widget _buildMobileHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button (if needed)
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        
        // Logo instead of title
        SvgPicture.asset(
          'assets/svg/logo/gymguideicon.svg',
          height: 42,
        ),
        
        // Spacer
        const Spacer(),
        
        // Right widget (optional)
        if (rightWidget != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: rightWidget!,
          ),
      ],
    );
  }
}
