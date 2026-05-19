import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
        final isDesktop = constraints.maxWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android;

        if (isDesktop) {
          return Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              child: Row(
                children: [
                // Permanent Sidebar for Desktop
                SidebarDrawer(
                  currentIndex: widget.currentIndex,
                  onItemSelected: widget.onItemSelected ?? (index) {
                    if (index >= 0) {
                      // Try ancestor lookup first (when inside MainScaffold tree)
                      final scaffoldFromTree = context.findAncestorStateOfType<MainScaffoldState>();
                      if (scaffoldFromTree != null) {
                        scaffoldFromTree.changeTab(index);
                        return;
                      }

                      // On a legal/overlay page — use globalKey to reach the root MainScaffold.
                      // Call changeTab first (it's already alive below this route),
                      // then pop this page to reveal it.
                      final globalScaffold = MainScaffold.globalKey.currentState;
                      if (globalScaffold != null) {
                        globalScaffold.changeTab(index);
                        Navigator.of(context).popUntil((route) => route.settings.name == '/' || route.isFirst);
                      } else {
                        // Last resort: navigate directly to the route
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
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
          ),
        );
      }

      // Mobile layout - just return child (it should be a Scaffold)
        return widget.child;
      },
    );
  }
}
