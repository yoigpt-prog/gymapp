import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/home_page.dart' show ExerciseDetail, ExerciseDetailCard;
import '../pages/main_scaffold.dart';
import '../widgets/red_header.dart';
import '../widgets/web_footer.dart';
import 'package:seo/seo.dart';

class ExercisePage extends StatefulWidget {
  final String slug;
  final String? initialGender;
  final String? initialView;
  final VoidCallback? toggleTheme;

  const ExercisePage({
    Key? key,
    required this.slug,
    this.initialGender,
    this.initialView,
    this.toggleTheme,
  }) : super(key: key);

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  bool _isLoading = true;
  ExerciseDetail? _exercise;

  @override
  void initState() {
    super.initState();
    _fetchExercise();
  }

  Future<void> _fetchExercise() async {
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select()
          .eq('exercise_slug', widget.slug)
          .maybeSingle();

      if (response != null && mounted) {
        var finalResponse = response;
        
        if (widget.initialGender != null) {
          final isFemaleRequested = widget.initialGender!.toLowerCase() == 'female';
          final baseIsFemale = response['is_female'] == true;
          
          if (isFemaleRequested != baseIsFemale) {
            final baseName = response['exercise_name'].toString().trim();
            final altResponse = await Supabase.instance.client
                .from('exercises')
                .select()
                .eq('is_female', isFemaleRequested)
                .ilike('exercise_name', '${baseName}%')
                .maybeSingle();
                
            if (altResponse != null) {
              finalResponse = altResponse;
            }
          }
        }
        
        setState(() {
          _exercise = ExerciseDetail.fromJson(finalResponse);
          _exercise = _exercise!.copyWith(slug: widget.slug);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching exercise by slug: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    Widget childWidget;

    if (_isLoading) {
      childWidget = Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(color: Color(0xFFFF0000)),
          ),
        ),
      );
    } else if (_exercise == null) {
      childWidget = Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            RedHeader(
              title: 'Exercise Not Found',
              onToggleTheme: widget.toggleTheme ?? () {},
              isDarkMode: isDarkMode,
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 80, color: isDarkMode ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 24),
                      Text(
                        'Exercise Not Found',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'The exercise you are looking for might have been removed or the URL is incorrect.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Back to Exercises', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            WebFooter(isDarkMode: isDarkMode),
          ],
        ),
      );
    } else {
      childWidget = MainScaffold(
        initialIndex: 0,
        initialExercise: _exercise,
        initialGender: widget.initialGender,
        initialView: widget.initialView,
        toggleTheme: widget.toggleTheme ?? () {},
        isDarkMode: isDarkMode,
      );
    }

    return Seo.head(
      tags: [
        if (_exercise != null) ...[
          MetaTag(name: 'title', content: '${_exercise!.name} - Muscles Worked, Instructions & Form | GymGuide'),
          MetaTag(name: 'description', content: 'Learn how to do ${_exercise!.name}, including target muscles, synergists, difficulty level, and step-by-step instructions.'),
          MetaTag(name: 'og:title', content: '${_exercise!.name} - Muscles Worked, Instructions & Form | GymGuide'),
          MetaTag(name: 'og:description', content: 'Learn how to do ${_exercise!.name}, including target muscles, synergists, difficulty level, and step-by-step instructions.'),
          MetaTag(name: 'og:url', content: 'https://www.gymguide.co/exercise/${_exercise!.slug}'),
          if (_exercise!.imagePath.isNotEmpty && !_exercise!.imagePath.toLowerCase().endsWith('.mp4'))
            MetaTag(name: 'og:image', content: _exercise!.imagePath),
        ],
      ],
      child: childWidget,
    );
  }
}
