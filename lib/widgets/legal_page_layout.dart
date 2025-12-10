import 'package:flutter/material.dart';
import 'main_layout_wrapper.dart';
import 'desktop_right_panel.dart';
import 'red_header.dart';

class LegalPageLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;
  final bool embedded;
  final bool showBanner;

  const LegalPageLayout({
    Key? key,
    required this.title,
    required this.child,
    required this.isDarkMode,
    this.onToggleTheme,
    this.embedded = false,
    this.showBanner = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          final content = Column(
            children: [
              // Header
              RedHeader(
                title: 'GymGuide',
                isDarkMode: isDarkMode,
                onToggleTheme: onToggleTheme,
              ),
              
              // Content Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 0, right: 8, top: 8, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Spacer (where sidebar is)
                            const SizedBox(width: 12),
                              
                              // Main Content - Stretched to fill height
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight - 16, // Stretch to fill available height
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                    // borderRadius removed
                                      border: Border.all(
                                        color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black,
                                        width: 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        child,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              if (showBanner) ...[
                                const SizedBox(width: 8),
                                
                                // Right Banner - Keep natural height (not stretched)
                                SizedBox(
                                  width: 280,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                      // borderRadius removed
                                      border: Border.all(
                                        color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black,
                                        width: 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: DesktopRightPanel(isDarkMode: isDarkMode),
                                  ),
                                ),
                              ],
                              
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );

          if (embedded) {
            return Container(
              color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
              child: content,
            );
          }

          return MainLayoutWrapper(
            isDarkMode: isDarkMode,
            child: content,
          );
        }

        // Mobile Layout
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          body: Column(
            children: [
              RedHeader(
                title: title,
                showBack: true,
                isDarkMode: isDarkMode,
                onToggleTheme: onToggleTheme,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
