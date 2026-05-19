import 'package:flutter/material.dart';
import '../widgets/legal_page_layout.dart';
import '../data/blog_content.dart';
import '../data/blog_articles.dart';
import 'blog_detail_page.dart';

class BlogPage extends StatefulWidget {
  final VoidCallback? toggleTheme;
  const BlogPage({super.key, this.toggleTheme});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  int _currentPage = 1;
  final int _itemsPerPage = 6;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final allArticles = blogArticles;

    final totalPages = (allArticles.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage > allArticles.length)
        ? allArticles.length
        : startIndex + _itemsPerPage;
    final visibleArticles = allArticles.sublist(startIndex, endIndex);

    return LegalPageLayout(
      onToggleTheme: widget.toggleTheme,
      title: 'Articles',
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 650;
              final crossAxisCount = isDesktop ? 2 : 1;
              const spacing = 24.0;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: 520, // Enforces exact uniform height
                ),
                itemCount: visibleArticles.length,
                itemBuilder: (context, index) {
                  final article = visibleArticles[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/blog/${article['slug']}');
                    },
                    child: ArticleCard(
                      title: article['title']!,
                      description: article['desc']!,
                      imagePath: article['image']!,
                      isDarkMode: isDarkMode,
                    ),
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 40),
          _buildPagination(totalPages, isDarkMode),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, bool isDarkMode) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        final isActive = page == _currentPage;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _currentPage = page;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFFFF0000) : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFFF0000)
                      : (isDarkMode ? Colors.white24 : Colors.black26),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                page.toString(),
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (isDarkMode ? Colors.white70 : Colors.black87),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ArticleCard extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final bool isDarkMode;

  const ArticleCard({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -6.0 : 0.0),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white12 : Colors.black12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.12 : 0.04),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image 16:9
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient overlay for modern look
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content text area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? const Color(0xFFD32F2F) : const Color(0xFFFF0000),
                      ),
                      child: const Text('Read More →'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
