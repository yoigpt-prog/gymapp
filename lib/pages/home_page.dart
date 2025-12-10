import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../widgets/red_header.dart';

class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const HomePage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _gender = 'male'; // 'male' or 'female'
  String _side = 'front';  // 'front' or 'back'
  String? _highlightedMuscle; // e.g. 'abs'
  String? _selectedMuscle; // For detail view

  // Pagination state
  final int _pageSize = 20;
  List<ExerciseDetail> _exercises = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  
  // Video Autoplay state
  int? _playingIndex;

  // Filter state
  bool _filterFavorites = false;
  Set<String> _selectedDifficulties = {};
  Set<String> _selectedWorkoutTypes = {};
  Set<String> _selectedEquipment = {};

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Scroll controller for hiding header
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _debugCheckData();
  }

  Future<void> _debugCheckData() async {
    try {
      // Fetch a sample of exercises to see what the data looks like
      final response = await Supabase.instance.client
          .from('exercises')
          .select('group_path, gender')
          .limit(20);
      
      debugPrint('--- SUPABASE DEBUG DATA ---');
      if (response.isEmpty) {
        debugPrint('No exercises found in DB at all!');
      } else {
        debugPrint('Found ${response.length} sample rows:');
        for (var row in response) {
          debugPrint('group_path: "${row['group_path']}", gender: "${row['gender']}"');
        }
      }
      debugPrint('---------------------------');
    } catch (e) {
      debugPrint('Error checking DB data: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _handleHeaderVisibility();
    _handlePagination();
    _handleVideoAutoplay();
  }

  void _handleHeaderVisibility() {
    final currentScrollOffset = _scrollController.offset;
    if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
      if (_showHeader) setState(() => _showHeader = false);
    } else if (currentScrollOffset < _lastScrollOffset) {
      if (!_showHeader) setState(() => _showHeader = true);
    }
    _lastScrollOffset = currentScrollOffset;
  }

  void _handlePagination() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      _loadMoreExercises();
    }
  }

  void _handleVideoAutoplay() {
    if (_selectedMuscle == null || _exercises.isEmpty) return;

    // Estimate item height (Card + margin)
    const double itemHeight = 550.0;
    
    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final centerOffset = scrollOffset + viewportHeight / 2;

    // Calculate index based on offset
    double listStartOffset = 150.0; 
    
    int newPlayingIndex = ((centerOffset - listStartOffset) / itemHeight).floor();
    
    if (newPlayingIndex < 0) newPlayingIndex = 0;
    if (newPlayingIndex >= _exercises.length) newPlayingIndex = _exercises.length - 1;

    if (_playingIndex != newPlayingIndex) {
      setState(() {
        _playingIndex = newPlayingIndex;
      });
    }
  }

  Future<void> _loadMoreExercises() async {
    if (_isLoading || !_hasMore || _selectedMuscle == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Handle potential casing mismatch in DB (e.g. 'chest' vs 'Chest')
      final muscle = _selectedMuscle!;
      final capitalizedMuscle = muscle[0].toUpperCase() + muscle.substring(1);
      
      // Use 'in' filter to match either lowercase or capitalized
      var query = Supabase.instance.client
          .from('exercises')
          .select()
          .inFilter('group_path', [muscle, capitalizedMuscle]);

      // Apply filters
      final capitalizedGender = _gender[0].toUpperCase() + _gender.substring(1);
      query = query.eq('gender', capitalizedGender);

      if (_selectedWorkoutTypes.isNotEmpty) {
        query = query.inFilter('exercise_type', _selectedWorkoutTypes.toList());
      }
      if (_selectedEquipment.isNotEmpty) {
        query = query.inFilter('equipment', _selectedEquipment.toList());
      }
      if (_selectedDifficulties.isNotEmpty) {
        query = query.inFilter('difficulty_level', _selectedDifficulties.toList());
      }

      // Apply comprehensive search query across multiple fields
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'exercise_name.ilike.%$_searchQuery%,'
          'group_path.ilike.%$_searchQuery%,'
          'target_muscle.ilike.%$_searchQuery%,'
          'equipment.ilike.%$_searchQuery%,'
          'synergist.ilike.%$_searchQuery%,'
          'exercise_type.ilike.%$_searchQuery%'
        );
      }

      final data = await query
          .order('exercise_name', ascending: true)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      final newExercises = (data as List).map((json) => ExerciseDetail.fromJson(json)).toList();

      setState(() {
        _exercises.addAll(newExercises);
        _currentPage++;
        _hasMore = newExercises.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetExercises() {
    setState(() {
      _exercises.clear();
      _currentPage = 0;
      _hasMore = true;
      _isLoading = false;
    });
    _loadMoreExercises();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      body: Column(
        children: [
          // Header (Animated)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showHeader ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showHeader ? 1.0 : 0.0,
              child: RedHeader(
                title: Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'Guest',
                subtitle: 'Welcome back',
                onToggleTheme: widget.toggleTheme,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          ),
          
          Expanded(
            child: _selectedMuscle == null
                ? Column(
                    children: [
                      _buildMobileSearchAndFilters(isDark, textColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 1080,
                              height: 1920,
                              child: Transform.scale(
                                scale: 1.08,
                                child: MuscleMap(
                                  gender: _gender,
                                  side: _side,
                                  highlightedMuscle: _highlightedMuscle,
                                  isDarkMode: isDark,
                                  onTapMuscle: (m) {
                                    setState(() {
                                      if (_highlightedMuscle == m) {
                                        _selectedMuscle = m;
                                        _resetExercises(); // Load exercises for selected muscle
                                      } else {
                                        _highlightedMuscle = m;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildMobileSearchAndFilters(isDark, textColor),
                      ),
                      
                      // Exercise List Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: textColor),
                                onPressed: () => setState(() {
                                  _selectedMuscle = null;
                                  _exercises.clear();
                                }),
                              ),
                              Expanded(
                                child: Text(
                                  '${_selectedMuscle![0].toUpperCase()}${_selectedMuscle!.substring(1)} Exercises',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Exercise List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= _exercises.length) {
                              return _isLoading
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                                  : const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: ExerciseDetailCard(
                                exercise: _exercises[index],
                                isDarkMode: isDark,
                                shouldPlay: index == _playingIndex,
                              ),
                            );
                          },
                          childCount: _exercises.length + (_isLoading ? 1 : 0),
                        ),
                      ),
                      
                      if (_exercises.isEmpty && !_isLoading)
                         SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No exercises found.',
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchAndFilters(bool isDark, Color textColor) {
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search, color: subTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search workouts, muscle...',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              _buildToggleChip(
                label: 'Male',
                isSelected: _gender == 'male',
                onTap: () {
                  setState(() => _gender = 'male');
                  if (_selectedMuscle != null) _resetExercises();
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildToggleChip(
                label: 'Female',
                isSelected: _gender == 'female',
                onTap: () {
                  setState(() => _gender = 'female');
                  if (_selectedMuscle != null) _resetExercises();
                },
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildToggleChip(
                label: 'Front',
                isSelected: _side == 'front',
                onTap: () => setState(() => _side = 'front'),
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildToggleChip(
                label: 'Back',
                isSelected: _side == 'back',
                onTap: () => setState(() => _side = 'back'),
                isDark: isDark,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showFilterModal(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune, size: 22, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
  final isDark = widget.isDarkMode;
  final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

  return Container(
    color: bgColor,
    child: Column(
      children: [
        // Custom Desktop Header
        RedHeader(
          title: 'GymGuide',
          onToggleTheme: widget.toggleTheme,
          isDarkMode: widget.isDarkMode,
          searchController: _searchController,
          onSearch: (query) {
            setState(() {
              _searchQuery = query;
              if (_selectedMuscle != null) {
                _resetExercises();
              }
            });
          },
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive panel widths (20% with min/max constraints)
              final availableWidth = constraints.maxWidth;
              final panelWidth = (availableWidth * 0.20).clamp(200.0, 280.0);
              final spacing = 12.0;
              
              return Stack(
                children: [
                  // Layer 1: Scrollable Content (Center) with Scrollbar at Screen Edge
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(spacing),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Spacer for Filters
                          SizedBox(width: panelWidth),
                          SizedBox(width: spacing),
                          // Actual Scrollable Center Content
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                border: Border.all(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _buildDesktopMuscleMap(),
                              ),
                            ),
                          ),
                          SizedBox(width: spacing),
                          // Spacer for Banner
                          SizedBox(width: panelWidth),
                        ],
                      ),
                    ),
                  ),

                  // Layer 2: Fixed Sidebars (Filters & Banner)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(spacing),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Fixed Filters
                          SizedBox(
                            width: panelWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                border: Border.all(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildDesktopFilterPanel(),
                            ),
                          ),
                          SizedBox(width: spacing),
                          // Spacer for Center (allows clicks to pass through)
                          const Expanded(child: SizedBox()),
                          SizedBox(width: spacing),
                          // Fixed Banner
                          SizedBox(
                            width: panelWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                border: Border.all(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildDesktopRightPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}


  Widget _buildDesktopFilterPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Gender Toggles
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildToggleChip(
                  label: 'Male',
                  isSelected: _gender == 'male',
                  onTap: () {
                    setState(() => _gender = 'male');
                    if (_selectedMuscle != null) _resetExercises();
                  },
                  isDark: widget.isDarkMode,
                  compact: true,
                ),
                _buildToggleChip(
                  label: 'Female',
                  isSelected: _gender == 'female',
                  onTap: () {
                    setState(() => _gender = 'female');
                    if (_selectedMuscle != null) _resetExercises();
                  },
                  isDark: widget.isDarkMode,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildFavoriteFilter(null, compact: true),
            const SizedBox(height: 12),
            _buildFilterSection('DIFFICULTY', [
              'Beginner',
              'Intermediate',
              'Advanced'
            ], _selectedDifficulties, null, compact: true),
            const SizedBox(height: 12),
            _buildFilterSection('WORKOUT TYPE', [
              'Strength',
              'Stretching',
              'Cardio'
            ], _selectedWorkoutTypes, null, compact: true),
            const SizedBox(height: 12),
            _buildFilterSection('EQUIPMENT', [
              'Assisted', 'Band', 'Barbell', 'Battling Rope', 'Body weight',
              'Bosu ball', 'Cable', 'Dumbbell', 'EZ Barbell', 'Kettlebell',
              'Leverage machine', 'Medicine Ball', 'Olympic barbell',
              'Pilates Machine', 'Power Sled', 'Resistance Band', 'Roll',
              'Rollball', 'Rope', 'Sled machine', 'Smith machine',
              'Stability ball', 'Stick', 'Suspension', 'Trap bar',
              'Vibrate Plate', 'Weighted', 'Wheel roller',
            ], _selectedEquipment, null, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMuscleMap() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_selectedMuscle != null) {
      return _buildDesktopExerciseList();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Muscles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              // Use 60% of viewport height, minus header and padding
              final muscleMapHeight = (screenHeight - 200).clamp(300.0, 800.0);
              return SizedBox(
                height: muscleMapHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: MuscleMap(
                        gender: _gender,
                        side: 'front',
                        highlightedMuscle: _highlightedMuscle,
                        isDarkMode: isDark,
                        onTapMuscle: (m) => _onMuscleTap(m),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: MuscleMap(
                        gender: _gender,
                        side: 'back',
                        highlightedMuscle: _highlightedMuscle,
                        isDarkMode: isDark,
                        onTapMuscle: (m) => _onMuscleTap(m),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopExerciseList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: widget.isDarkMode ? Colors.white : Colors.black87),
                onPressed: () {
                  setState(() {
                    _selectedMuscle = null;
                    _exercises.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedMuscle![0].toUpperCase()}${_selectedMuscle!.substring(1)} Exercises',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _exercises.isEmpty && !_isLoading
            ? Center(child: Text('No exercises found.', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black)))
            : ListView.builder(
                padding: const EdgeInsets.all(0), // Reduced from 24 to 0 to reduce gap
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _exercises.length) {
                    return _isLoading
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ExerciseDetailCard(
                      exercise: _exercises[index],
                      isDarkMode: widget.isDarkMode,
                      shouldPlay: false,
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _onMuscleTap(String m) {
  setState(() {
    if (_highlightedMuscle == m) {
      // Proceed with muscle selection directly
      _selectedMuscle = m;
      _resetExercises();
    } else {
      _highlightedMuscle = m;
    }
  }); 
}

  void _showGoogleSignInDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent, // No dark overlay
      builder: (BuildContext context) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, right: 40),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDarkMode ? const Color(0xFF404040) : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Google logo and close button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Google Logo
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  foreground: Paint()
                                    ..shader = const LinearGradient(
                                      colors: [
                                        Color(0xFF4285F4),
                                        Color(0xFFEA4335),
                                        Color(0xFFFBBC05),
                                        Color(0xFF34A853),
                                      ],
                                    ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Text(
                              'Sign in to GymGuide with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: widget.isDarkMode ? Colors.white : const Color(0xFF202124),
                              ),
                            ),
                          ),
                          // Close button
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF5F6368),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 1),
                    
                    // Profile Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // User Avatar placeholder
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'U',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A73E8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // User Info placeholder
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDarkMode ? Colors.white : const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDarkMode ? Colors.white70 : const Color(0xFF5F6368),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Continue Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.auth.signInWithOAuth(
                                OAuthProvider.google,
                                redirectTo: 'io.supabase.gymguideapp://login-callback/',
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error signing in: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Disclaimer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        'To continue, Google will share your name, email address, and profile picture with this site.',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDarkMode ? Colors.white60 : const Color(0xFF5F6368),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopRightPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 0 ? constraints.maxHeight - 24 : 0,
              ),
              child: Center(
                child: Image.asset(
                  'assets/banner/adbanner.png',
                  fit: BoxFit.contain,
                  width: constraints.maxWidth - 24, // Account for padding
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 4 : 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0000) : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 14,
              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            _buildFavoriteFilter(setModalState),
                            const SizedBox(height: 24),
                            _buildFilterSection('DIFFICULTY', [
                              'Beginner', 'Intermediate', 'Advanced'
                            ], _selectedDifficulties, setModalState),
                            const SizedBox(height: 24),
                            _buildFilterSection('WORKOUT TYPE', [
                              'Strength', 'Stretching', 'Cardio'
                            ], _selectedWorkoutTypes, setModalState),
                            const SizedBox(height: 24),
                            _buildFilterSection('EQUIPMENT', [
                              'Assisted', 'Band', 'Barbell', 'Battling Rope', 'Body weight',
                              'Bosu ball', 'Cable', 'Dumbbell', 'EZ Barbell', 'Kettlebell',
                              'Leverage machine', 'Medicine Ball', 'Olympic barbell',
                              'Pilates Machine', 'Power Sled', 'Resistance Band', 'Roll',
                              'Rollball', 'Rope', 'Sled machine', 'Smith machine',
                              'Stability ball', 'Stick', 'Suspension', 'Trap bar',
                              'Vibrate Plate', 'Weighted', 'Wheel roller',
                            ], _selectedEquipment, setModalState),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                              width: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() {
                                    _filterFavorites = false;
                                    _selectedDifficulties.clear();
                                    _selectedWorkoutTypes.clear();
                                    _selectedEquipment.clear();
                                  });
                                  setState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF0000),
                                  side: const BorderSide(color: Color(0xFFFF0000)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Reset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {});
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF0000),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteFilter(StateSetter? setModalState, {bool compact = false}) {
    void updateState(VoidCallback fn) {
      if (setModalState != null) {
        setModalState(fn);
        setState(() {});
      } else {
        setState(fn);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            'FAVORITE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF4A5568),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Compact mode with header
          Text(
            'FAVORITE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white54 : const Color(0xFF718096),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () {
            updateState(() {
              _filterFavorites = !_filterFavorites;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 4 : 8),
            decoration: BoxDecoration(
              color: _filterFavorites ? const Color(0xFFFF0000) : (widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _filterFavorites ? const Color(0xFFFF0000) : const Color(0xFFE2E8F0),
                width: compact ? 1.0 : 0.3,
              ),
            ),
            child: Text(
              'Show Favorites Only',
              style: TextStyle(
                fontSize: compact ? 11 : 14,
                fontWeight: FontWeight.w600,
                color: _filterFavorites ? Colors.white : (widget.isDarkMode ? Colors.white : const Color(0xFF2D3748)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(String title, List<String> options, Set<String> selectedSet, StateSetter? setModalState, {bool compact = false}) {
    void updateState(VoidCallback fn) {
      if (setModalState != null) {
        setModalState(fn);
        setState(() {});
      } else {
        setState(fn);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF4A5568),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Compact mode with header
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white54 : const Color(0xFF718096),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: compact ? 6 : 10,
          runSpacing: compact ? 6 : 10,
          children: options.map((option) {
            final isSelected = selectedSet.contains(option);
            return GestureDetector(
              onTap: () {
                updateState(() {
                  if (isSelected) {
                    selectedSet.remove(option);
                  } else {
                    selectedSet.add(option);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 4 : 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF0000) : (widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF0000) : const Color(0xFFE2E8F0),
                    width: compact ? 1.0 : 0.3,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white : const Color(0xFF2D3748)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ExerciseDetail {
  final String name;
  final String muscleId;
  final String imagePath;
  final String target;
  final String synergists;
  final String difficulty;
  final List<String> steps;
  final String? gender;
  final String? exerciseType;
  final String? equipment;

  ExerciseDetail({
    required this.name,
    required this.muscleId,
    required this.imagePath,
    required this.target,
    required this.synergists,
    required this.difficulty,
    required this.steps,
    this.gender,
    this.exerciseType,
    this.equipment,
  });

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    // Helper to get non-null string
    String getString(String key, {String defaultVal = ''}) {
      return json[key]?.toString() ?? defaultVal;
    }

    // Collect instructions
    List<String> instructions = [];
    for (int i = 1; i <= 4; i++) {
      final step = json['instruction_$i']?.toString();
      if (step != null && step.isNotEmpty) {
        instructions.add(step);
      }
    }
    // Fallback if no instructions found
    if (instructions.isEmpty) {
      instructions = ['Follow the video demonstration.'];
    }

    return ExerciseDetail(
      name: getString('exercise_name', defaultVal: 'Unknown Exercise'),
      muscleId: getString('group_path'),
      imagePath: getString('urls'),
      target: getString('target_muscle', defaultVal: getString('target', defaultVal: (json['group_path'] as String? ?? 'General').toUpperCase())),
      synergists: getString('synergist', defaultVal: getString('synergists', defaultVal: getString('syntects', defaultVal: 'Various'))),
      difficulty: getString('difficulty_level', defaultVal: getString('difficulty', defaultVal: 'Intermediate')),
      steps: instructions,
      gender: getString('gender'),
      exerciseType: getString('exercise_type'),
      equipment: getString('equipment'),
    );
  }
}

class ExerciseDetailCard extends StatefulWidget {
  final ExerciseDetail exercise;
  final bool isDarkMode;
  final bool shouldPlay; // Added for autoplay support

  const ExerciseDetailCard({
    Key? key,
    required this.exercise,
    required this.isDarkMode,
    this.shouldPlay = false,
  }) : super(key: key);

  @override
  State<ExerciseDetailCard> createState() => _ExerciseDetailCardState();
}

class _ExerciseDetailCardState extends State<ExerciseDetailCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(
          color: isDarkMode ? Colors.white : Colors.black,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            color: const Color(0xFFFF0000),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: () {
                    setState(() {
                      _isFavorite = !_isFavorite;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Video/Image Preview
          Container(
            width: double.infinity,
            color: isDarkMode ? Colors.black26 : Colors.grey.shade100,
            child: widget.exercise.imagePath.isNotEmpty
                ? _buildMediaPreview(widget.exercise.imagePath, isDarkMode)
                : SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata Table
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (widget.exercise.target.isNotEmpty) 
                        _buildInfoRow('Target muscle:', widget.exercise.target, textColor, subTextColor),
                      if (widget.exercise.synergists.isNotEmpty) 
                        _buildInfoRow('Synergists:', widget.exercise.synergists, textColor, subTextColor),
                      if (widget.exercise.difficulty.isNotEmpty) 
                        _buildInfoRow('Difficulty:', widget.exercise.difficulty, textColor, subTextColor),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // Instructions
                if (widget.exercise.steps.isNotEmpty) ...[
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.exercise.steps.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF0000),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: subTextColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor, Color subTextColor) {
    final borderColor = widget.isDarkMode ? Colors.white24 : Colors.black12;
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label cell
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF0000),
                ),
              ),
            ),
            // Value cell
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String url, bool isDarkMode) {
    // Simple check for video extensions
    final cleanUrl = url.trim();
    final isVideo = cleanUrl.toLowerCase().endsWith('.mp4') ||
        cleanUrl.toLowerCase().endsWith('.mov') ||
        cleanUrl.toLowerCase().endsWith('.webm');

    if (isVideo) {
      return VideoPlayerWidget(videoUrl: cleanUrl);
    } else {
      return Image.network(
        cleanUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Mute for autoplay
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}

/// Muscle map widget handling multiple muscles
class MuscleMap extends StatelessWidget {
  final String gender; // 'male' or 'female'
  final String side;   // 'front' or 'back'
  final String? highlightedMuscle;
  final ValueChanged<String> onTapMuscle;
  final bool isDarkMode;

  const MuscleMap({
    Key? key,
    required this.gender,
    required this.side,
    required this.highlightedMuscle,
    required this.onTapMuscle,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // folders like: assets/svg/male/front/base_day.svg, abs.svg, chest.svg, etc.
    final basePath = 'assets/svg/$gender/$side';

    // Define available muscles based on side
    final List<String> muscles = side == 'front'
        ? [
            'abs',
            'chest',
            'biceps',
            'shoulders',
            'thighs',
            'obliques',
            'traps',
            'forarms',
            'neck'
          ]
        : [
            'lats',
            'lowerback',
            'traps',
            'shoulders',
            'triceps',
            'forarms',
            'hipsandglutes',
            'hamstrings',
            'calves'
          ];

    // Debug flag to show hit boxes
    const bool showDebugBoxes = false;

    // Define regions based on SVG analysis (approximate relative coordinates)
    final List<MuscleRegion> regions = side == 'front'
        ? [
            MuscleRegion(id: 'neck', left: 0.42, top: 0.09, width: 0.16, height: 0.07, label: 'Neck'),
            MuscleRegion(id: 'traps', left: 0.32, top: 0.11, width: 0.36, height: 0.06, label: 'Traps'),
            MuscleRegion(id: 'shoulders', left: 0.18, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'), // Left
            MuscleRegion(id: 'shoulders', left: 0.64, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'), // Right
            MuscleRegion(id: 'chest', left: 0.30, top: 0.18, width: 0.40, height: 0.11, label: 'Chest'),
            MuscleRegion(id: 'biceps', left: 0.12, top: 0.28, width: 0.16, height: 0.12, label: 'Bic'), // Left
            MuscleRegion(id: 'biceps', left: 0.72, top: 0.28, width: 0.16, height: 0.12, label: 'Bic'), // Right
            MuscleRegion(id: 'forarms', left: 0.06, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'), // Left
            MuscleRegion(id: 'forarms', left: 0.76, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'), // Right
            MuscleRegion(id: 'abs', left: 0.38, top: 0.29, width: 0.24, height: 0.16, label: 'Abs'),
            MuscleRegion(id: 'obliques', left: 0.30, top: 0.32, width: 0.08, height: 0.12, label: 'Obl'), // Left
            MuscleRegion(id: 'obliques', left: 0.62, top: 0.32, width: 0.08, height: 0.12, label: 'Obl'), // Right
            MuscleRegion(id: 'thighs', left: 0.28, top: 0.50, width: 0.44, height: 0.25, label: 'Thighs'),
          ]
        : [
            MuscleRegion(id: 'traps', left: 0.35, top: 0.10, width: 0.30, height: 0.06, label: 'Traps'),
            MuscleRegion(id: 'shoulders', left: 0.18, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'),
            MuscleRegion(id: 'shoulders', left: 0.64, top: 0.16, width: 0.18, height: 0.12, label: 'Shldr'),
            MuscleRegion(id: 'lats', left: 0.30, top: 0.22, width: 0.40, height: 0.18, label: 'Lats'),
            MuscleRegion(id: 'lowerback', left: 0.38, top: 0.40, width: 0.24, height: 0.08, label: 'LowBk'),
            MuscleRegion(id: 'triceps', left: 0.15, top: 0.26, width: 0.14, height: 0.12, label: 'Tri'),
            MuscleRegion(id: 'triceps', left: 0.71, top: 0.26, width: 0.14, height: 0.12, label: 'Tri'),
            MuscleRegion(id: 'forarms', left: 0.06, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'),
            MuscleRegion(id: 'forarms', left: 0.76, top: 0.40, width: 0.18, height: 0.18, label: 'Farm'),
            MuscleRegion(id: 'hipsandglutes', left: 0.30, top: 0.48, width: 0.40, height: 0.14, label: 'Glutes'),
            MuscleRegion(id: 'hamstrings', left: 0.30, top: 0.62, width: 0.40, height: 0.16, label: 'Hams'),
            MuscleRegion(id: 'calves', left: 0.30, top: 0.78, width: 0.40, height: 0.14, label: 'Calves'),
          ];

    return AspectRatio(
      aspectRatio: 1080 / 1920, // Match SVG aspect ratio
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localPosition = details.localPosition;
              final Size size = box.size;
              
              // Normalize coordinates (0.0 to 1.0)
              final double dx = localPosition.dx / size.width;
              final double dy = localPosition.dy / size.height;



              for (final region in regions) {
                if (dx >= region.left && dx <= region.left + region.width &&
                    dy >= region.top && dy <= region.top + region.height) {

                  onTapMuscle(region.id);
                  break;
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base outline
                SvgPicture.asset(
                  '$basePath/base_day.svg',
                  fit: BoxFit.contain,
                  colorFilter: isDarkMode
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : null,
                ),

                // Muscle layers (Visual only, no interaction)
                ...muscles.map((muscle) => IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: highlightedMuscle == muscle ? 1.0 : 0.0,
                        child: SvgPicture.asset(
                          '$basePath/$muscle.svg',
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            const Color(0xFFFF0000).withOpacity(0.85),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    )),
                
                // Debug overlay
                if (showDebugBoxes)
                  CustomPaint(
                    size: Size.infinite,
                    painter: HitBoxPainter(regions: regions),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MuscleRegion {
  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final String label;

  MuscleRegion({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.label,
  });
}

class HitBoxPainter extends CustomPainter {
  final List<MuscleRegion> regions;
  HitBoxPainter({required this.regions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final region in regions) {
      final rect = Rect.fromLTWH(
        region.left * size.width,
        region.top * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
      
      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: region.label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, rect.center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
