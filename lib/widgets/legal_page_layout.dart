import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'main_layout_wrapper.dart';
import 'red_header.dart';

class LegalPageLayout extends StatefulWidget {
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
  State<LegalPageLayout> createState() => _LegalPageLayoutState();
}

class _LegalPageLayoutState extends State<LegalPageLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800 && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android;

        if (isDesktop) {
          // Responsive ad panel: 22% of screen width, clamped to [200, 320]
          final adPanelWidth =
              (constraints.maxWidth * 0.22).clamp(200.0, 320.0);
          final adAsset = widget.isDarkMode
              ? 'assets/banner/adblackmode.png'
              : 'assets/banner/adwhitemode.png';

          const double spacing = 16.0;

          final content = Column(
            children: [
              // Header
              RedHeader(
                title: 'GymGuide',
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),

              // Content + Ad Stack
              Expanded(
                child: Stack(
                  children: [
                    // Layer 1: Scrollable Content with Scrollbar on far right
                    Positioned.fill(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(spacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main content area
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    border: Border.all(
                                      color: widget.isDarkMode ? Colors.white : Colors.black,
                                      width: 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: widget.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      widget.child,
                                    ],
                                  ),
                                ),
                              ),
                              if (widget.showBanner) ...[
                                const SizedBox(width: spacing),
                                SizedBox(width: adPanelWidth), // Spacer for Ad
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Layer 2: Fixed Ad Panel
                    if (widget.showBanner)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(spacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(child: SizedBox()), // Allows clicks to pass through
                              const SizedBox(width: spacing),
                              SizedBox(
                                width: adPanelWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    border: Border.all(
                                      color: widget.isDarkMode ? Colors.white : Colors.black,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 50),
                                          child: Image.asset(
                                            adAsset,
                                            key: ValueKey(adAsset),
                                            fit: BoxFit.fill,
                                            width: constraints.maxWidth,
                                            height: constraints.maxHeight,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

          if (widget.embedded) {
            return Container(
              color: widget.isDarkMode
                  ? const Color(0xFF121212)
                  : const Color(0xFFF5F7FA),
              child: content,
            );
          }

          return MainLayoutWrapper(
            isDarkMode: widget.isDarkMode,
            child: content,
          );
        }

        // Mobile Layout — unchanged
        return Scaffold(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor:
                widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   widget.child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
