import 'package:flutter/material.dart';
import 'sidebar_drawer.dart';
import 'web_footer.dart';
import '../pages/main_scaffold.dart';

class MainLayoutWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final bool isDarkMode;
  final Function(int)? onItemSelected;

  const MainLayoutWrapper({
    Key? key,
    required this.child,
    this.currentIndex = -1, // Default to no selection
    required this.isDarkMode,
    this.onItemSelected,
  }) : super(key: key);

  @override
  State<MainLayoutWrapper> createState() => _MainLayoutWrapperState();
}

class _MainLayoutWrapperState extends State<MainLayoutWrapper> {
  final GlobalKey<WebFooterState> _footerKey = GlobalKey<WebFooterState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
            body: Row(
              children: [
                // Permanent Sidebar for Desktop
                SidebarDrawer(
                  currentIndex: widget.currentIndex,
                  onItemSelected: widget.onItemSelected ?? (index) {
                    // If no handler provided, navigate to MainScaffold with the selected index
                    if (index != widget.currentIndex) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => MainScaffold(
                            toggleTheme: () {}, // Theme toggle is handled internally or via state
                            isDarkMode: widget.isDarkMode,
                            initialIndex: index,
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  isDarkMode: widget.isDarkMode,
                ),
                // Main Content with Footer
                Expanded(
                  child: Column(
                    children: [
                      // Main Content Area
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // Footer scroll logic removed/disabled as per requirement
                            // _footerKey.currentState?.onScroll(notification);
                            return false;
                          },
                          child: widget.child,
                        ),
                      ),
                      
                      // Footer (Fixed at bottom)
                      WebFooter(
                        key: _footerKey,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile layout - just return child (it should be a Scaffold)
        return widget.child;
      },
    );
  }
}
