import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/main_layout_wrapper.dart';
import '../widgets/red_header.dart';
import '../data/blog_articles.dart';

class BlogDetailPage extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final String filePath;
  final String category;
  final VoidCallback? toggleTheme;

  const BlogDetailPage({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.filePath,
    required this.category,
    this.toggleTheme,
  }) : super(key: key);

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
    _scrollController.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _readingProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    });
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString(widget.filePath);
      if (mounted) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load article content.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    final content = Column(
      children: [
        // Top Header
        RedHeader(
          title: 'GymGuide',
          isDarkMode: isDarkMode,
          onToggleTheme: widget.toggleTheme,
        ),
        
        // Reading Progress Bar
        if (_readingProgress > 0)
          LinearProgressIndicator(
            value: _readingProgress,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 3,
          ),

        // Main Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _buildHeroSection(isDarkMode, isDesktop),
                _buildArticleContent(isDarkMode, isDesktop),
                _buildRelatedArticles(isDarkMode, isDesktop),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );

    return MainLayoutWrapper(
      isDarkMode: isDarkMode,
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: content,
      ),
    );
  }

  Widget _buildHeroSection(bool isDarkMode, bool isDesktop) {
    return Container(
      width: double.infinity,
      height: isDesktop ? 500 : 350,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            widget.imagePath,
            fit: BoxFit.cover,
          ),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          
          // Cinematic Blur Effect (optional, subtle)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Hero Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 20, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.category.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Metadata
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '10 MIN READ',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Back button for mobile (if not in layout)
          if (!isDesktop)
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleContent(bool isDarkMode, bool isDesktop) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isDesktop ? 60 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BACK TO ARTICLES',
                      style: GoogleFonts.outfit(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              if (_isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 100),
                  child: CircularProgressIndicator(color: Color(0xFFFF0000)),
                ))
              else if (_error != null)
                Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              else if (_markdownContent != null)
                MarkdownBody(
                  data: _markdownContent!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.outfit(
                      fontSize: 18,
                      height: 1.8,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF222222),
                      fontWeight: FontWeight.w400,
                    ),
                    h1: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1.3,
                    ),
                    h2: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1.4,
                    ),
                    h3: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1.4,
                    ),
                    blockSpacing: 32,
                    listBullet: TextStyle(
                      color: isDarkMode ? Colors.white70 : const Color(0xFF222222),
                      fontSize: 18,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: Color(0xFFFF0000), width: 4),
                      ),
                    ),
                    blockquotePadding: const EdgeInsets.all(24),
                    blockquote: GoogleFonts.outfit(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 60),
              const Divider(),
              const SizedBox(height: 30),
              
              // Share Section
              Row(
                children: [
                  Text(
                    'SHARE THIS ARTICLE',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _buildShareIcon(Icons.link, isDarkMode, () {
                    final url = Uri.base.toString();
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  }),
                  const SizedBox(width: 12),
                  _buildShareIcon(Icons.facebook, isDarkMode, () async {
                    final url = Uri.base.toString();
                    final fbUrl = 'https://www.facebook.com/sharer/sharer.php?u=$url';
                    if (await canLaunchUrl(Uri.parse(fbUrl))) {
                      await launchUrl(Uri.parse(fbUrl), mode: LaunchMode.externalApplication);
                    }
                  }),
                  const SizedBox(width: 12),
                  _buildShareIcon(Icons.share, isDarkMode, () {
                    final url = Uri.base.toString();
                    Share.share('Check out this article: ${widget.title}\n$url');
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareIcon(IconData icon, bool isDarkMode, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode ? Colors.white12 : Colors.grey[100],
        ),
        child: Icon(icon, size: 20, color: isDarkMode ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildRelatedArticles(bool isDarkMode, bool isDesktop) {
    // Show 3 related articles (different from current)
    final related = blogArticles.where((a) => a['title'] != widget.title).take(3).toList();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'RELATED ARTICLES',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            isDesktop 
              ? Row(
                  children: related.map((a) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildRelatedCard(a, isDarkMode),
                    ),
                  )).toList(),
                )
              : Column(
                  children: related.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRelatedCard(a, isDarkMode),
                  )).toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedCard(Map<String, String> article, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacementNamed(context, '/blog/${article['slug']}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(article['image']!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            article['title']!,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
