import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/physique_service.dart';
import '../../models/physique_analysis_model.dart';
import '../../services/revenue_cat_service.dart';
import '../custom_plan_quiz.dart';
import '../main_scaffold.dart';

class PhysiqueScanPage extends StatefulWidget {
  final bool isDarkMode;
  const PhysiqueScanPage({Key? key, this.isDarkMode = false}) : super(key: key);

  @override
  State<PhysiqueScanPage> createState() => _PhysiqueScanPageState();
}

class _PhysiqueScanPageState extends State<PhysiqueScanPage>
    with TickerProviderStateMixin {
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  bool _isLoadingCache = true;
  String _statusMessage = 'Uploading image...';
  PhysiqueAnalysis? _result;
  PhysiqueValidationException? _validationError;
  String? _errorMessage;

  late AnimationController _scanController;
  late AnimationController _fadeController;
  late Animation<double> _scanAnimation;
  late Animation<double> _fadeAnimation;

  final _picker = ImagePicker();
  final _service = PhysiqueService();

  static const _red = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _loadCachedResult();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedResult() async {
    setState(() => _isLoadingCache = true);
    try {
      final cached = await _service.getLastCompletedAnalysis();
      if (mounted && cached != null) {
        setState(() => _result = cached);
        _fadeController.forward();
      }

      // Check yearly limit to display error immediately if reached
      final year = DateTime.now().year;
      final usage = await _service.getYearlyUsage('rate_my_physique', year);
      if (usage >= 3 && mounted) {
        setState(() {
          _errorMessage = 'You’ve reached your  limit for Rate My Physique AI. Please try again .';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCache = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _result = null;
          _errorMessage = null;
          _validationError = null;
        });
        _fadeController.reset();
        await _runAnalysis(bytes);
      }
    } catch (e) {
      debugPrint('[PhysiqueScan] pick error: $e');
    }
  }

  Future<void> _runAnalysis(Uint8List bytes) async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Uploading image...';
      _errorMessage = null;
      _validationError = null;
    });

    try {
      final result = await _service.analyzePhysique(
        bytes,
        onStatus: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _result = result;
      });
      _fadeController.forward(from: 0);
    } on PhysiqueValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _validationError = e;
      });
    } catch (e) {
      debugPrint('[PhysiqueScan] analysis error: $e');
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _checkUsageAndShowSourceModal() async {
    setState(() {
      _errorMessage = null;
      _validationError = null;
    });

    try {
      final year = DateTime.now().year;
      final usage = await _service.getYearlyUsage('rate_my_physique', year);
      if (usage >= 3) {
        if (mounted) {
          setState(() {
            _errorMessage = 'You’ve reached your  limit for Rate My Physique AI. Please try again .';
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[PhysiqueScan] getYearlyUsage error: $e');
    }

    if (!mounted) return;
    _showSourceModal();
  }

  void _showSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourceSheet(
        onCamera: () {
          Navigator.pop(context);
          _pickImage(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(context);
          _pickImage(ImageSource.gallery);
        },
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.1);
    final leadingBtnBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: textColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: leadingBtnBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new,
                size: 18, color: textColor),
          ),
        ),
        title: Text('Rate My Physique AI',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: dividerColor),
        ),
      ),
      body: _isLoadingCache
          ? const Center(
              child: CircularProgressIndicator(color: _red, strokeWidth: 2.5))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildUploadArea(),
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 28),
                    _buildAnalyzingState(),
                  ],
                  if (_validationError != null) ...[
                    const SizedBox(height: 20),
                    _buildValidationCard(_validationError!),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorCard(),
                  ],
                  if (_result != null && !_isAnalyzing) ...[
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _PhysiqueResultSection(
                        result: _result!,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  ],
                  if (_result == null &&
                      !_isAnalyzing &&
                      _errorMessage == null &&
                      _validationError == null) ...[
                    const SizedBox(height: 24),
                    _buildTips(),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final bool isDark = widget.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _red.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.accessibility_new_rounded, color: _red, size: 14),
              const SizedBox(width: 6),
              Text('AI BODY SCAN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _red,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Rate My\nPhysique AI',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                height: 1.1)),
        const SizedBox(height: 8),
        Text(
          'Upload a full body photo and get your detailed AI physique analysis.',
          style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildUploadArea() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    return GestureDetector(
      onTap: _checkUsageAndShowSourceModal,
      child: Container(
        width: double.infinity,
        height: _imageBytes != null ? 260 : 180,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _imageBytes != null
                ? (_validationError != null ? _red : borderColor)
                : borderColor,
            width: _imageBytes != null ? 2 : 1,
          ),
        ),
        child: _imageBytes != null
            ? _buildImagePreview()
            : _buildEmptyUpload(),
      ),
    );
  }

  Widget _buildEmptyUpload() {
    final bool isDark = widget.isDarkMode;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: _red.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(Icons.person_search_outlined, color: _red, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Upload Full Body Photo',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text('Camera or Gallery',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
        ),
        if (_isAnalyzing)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        if (_isAnalyzing)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (_, __) => Align(
                alignment: Alignment(0, _scanAnimation.value),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _red.withOpacity(0),
                      _red,
                      _red.withOpacity(0),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        if (!_isAnalyzing)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _checkUsageAndShowSourceModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Change Photo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: _red, strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 4),
                Text('This usually takes 10-20 seconds',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCard(PhysiqueValidationException error) {
    final bool isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.image_not_supported_outlined, color: _red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _red)),
                const SizedBox(height: 4),
                Text(error.message,
                    style: TextStyle(
                        fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final bool isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(
                    fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final steps = [
      'Stand in front of a plain wall',
      'Ensure full body is visible',
      'Use good, even lighting',
      'Face the camera directly',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.tips_and_updates_outlined, size: 17, color: _red),
            const SizedBox(width: 8),
            Text('Tips for Best Results',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black)),
          ]),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: _red.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _red)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(e.value,
                        style: TextStyle(
                            fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Source Sheet ──────────────────────────────────────────────────────────────

class _SourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool isDarkMode;
  const _SourceSheet({
    required this.onCamera,
    required this.onGallery,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDarkMode ? Colors.white10 : Colors.black12;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Upload Photo',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
          ),
          const SizedBox(height: 16),
          _option(Icons.camera_alt_outlined, 'Take Photo', onCamera, textColor),
          Divider(height: 1, color: borderColor),
          _option(Icons.photo_library_outlined, 'Choose from Gallery', onGallery, textColor),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _option(IconData icon, String label, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFFFF0000)),
            ),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}

// ── Result Section ────────────────────────────────────────────────────────────

class _PhysiqueResultSection extends StatefulWidget {
  final PhysiqueAnalysis result;
  final bool isDarkMode;
  const _PhysiqueResultSection({
    required this.result,
    required this.isDarkMode,
  });

  @override
  State<_PhysiqueResultSection> createState() => _PhysiqueResultSectionState();
}

class _PhysiqueResultSectionState extends State<_PhysiqueResultSection> {
  static const _red = Color(0xFFFF0000);

  bool _hasCompletedQuiz = false;
  bool _isPremium = false;
  bool _isLoadingUserState = true;

  @override
  void initState() {
    super.initState();
    _checkUserState();
  }

  Future<void> _checkUserState() async {
    setState(() => _isLoadingUserState = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedQuiz = prefs.getBool('hasCompletedQuiz') ?? false;
      _isPremium = await RevenueCatService().isProUser();
    } catch (e) {
      debugPrint('[PhysiqueScan] Error loading user state: $e');
    }
    if (mounted) {
      setState(() => _isLoadingUserState = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR ANALYSIS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(height: 16),

        _buildOverallScore(),
        const SizedBox(height: 16),

        _buildBreakdown(),
        const SizedBox(height: 16),

        _buildChipCard(
          'Strengths',
          Icons.star_outline_rounded,
          Colors.green.shade600,
          widget.result.strengths,
          isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
          isDark ? Colors.green.shade700.withOpacity(0.4) : Colors.green.shade200,
        ),
        const SizedBox(height: 12),

        _buildChipCard(
          'Focus Areas',
          Icons.flag_outlined,
          _red,
          widget.result.focusAreas,
          _red.withOpacity(isDark ? 0.15 : 0.06),
          _red.withOpacity(isDark ? 0.35 : 0.2),
        ),
        const SizedBox(height: 12),

        _buildBodyTypeCard(),
        const SizedBox(height: 12),

        _buildSummaryCard(),
        const SizedBox(height: 24),

        _buildCTA(context),
        const SizedBox(height: 20),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildOverallScore() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black;

    final score = widget.result.overallScore;
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(isDark ? 0.05 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: score),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value / 10,
                        strokeWidth: 7,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Physique Score',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
                const SizedBox(height: 4),
                Text(widget.result.scoreLabel,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 4),
                Text('Rated out of 10.0',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black;

    final primary = widget.result.breakdown.primaryEntries();
    final secondary = widget.result.breakdown.secondaryEntries();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Physique Breakdown',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor)),
          const SizedBox(height: 16),
          ...primary.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BreakdownRow(label: e.key, score: e.value, isDarkMode: isDark),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06), height: 1),
          ),
          const SizedBox(height: 14),
          ...secondary.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BreakdownRow(label: e.key, score: e.value, isSecondary: true, isDarkMode: isDark),
              )),
        ],
      ),
    );
  }

  Widget _buildChipCard(String title, IconData icon, Color iconColor,
      List<String> items, Color chipBg, Color chipBorder) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipBorder),
                ),
                child: Text(item,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyTypeCard() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.person_outline_rounded, color: _red, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Body Type Detected',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black45)),
                const SizedBox(height: 3),
                Text(widget.result.bodyType,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final bool isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: _red, size: 18),
              const SizedBox(width: 8),
              Text('AI Summary',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.result.aiSummary,
              style: TextStyle(
                  fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildCTA(BuildContext context) {
    if (_isLoadingUserState) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _red.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final String buttonText;
    final VoidCallback onTap;

    if (!_hasCompletedQuiz) {
      buttonText = 'Start My Transformation Plan';
      onTap = () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomPlanQuizPage(quizType: 'workout'),
          ),
        );
        if (result is Map && result['completed'] == true) {
          if (mounted) {
            MainScaffold.globalKey.currentState?.refreshAllPages();
            final targetTab = result['navIndex'] ?? 1;
            Navigator.pop(context); // Close PhysiqueScanPage
            MainScaffold.globalKey.currentState?.changeTab(targetTab);
            return;
          }
        }
        _checkUserState();
      };
    } else if (!_isPremium) {
      buttonText = 'Unlock My Full Plan';
      onTap = () async {
        await RevenueCatService().showPaywall();
        _checkUserState();
        if (mounted) {
          context.findAncestorStateOfType<MainScaffoldState>()?.refreshAllPages();
        }
      };
    } else {
      buttonText = 'Open My Plan';
      onTap = () {
        Navigator.pop(context);
        MainScaffold.globalKey.currentState?.changeTab(1);
      };
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _red.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Text(
            buttonText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    final bool isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'These scores are AI estimates for motivational guidance only. Not medical advice.',
              style: TextStyle(
                  fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 8.0) return Colors.green.shade600;
    if (score >= 6.0) return _red;
    return _red;
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double score;
  final bool isSecondary;
  final bool isDarkMode;
  static const _red = Color(0xFFFF0000);

  const _BreakdownRow({
    required this.label,
    required this.score,
    this.isSecondary = false,
    required this.isDarkMode,
  });

  Color get _color {
    if (score >= 8.0) return Colors.green.shade600;
    if (score >= 6.0) return _red;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSecondary ? FontWeight.w500 : FontWeight.w600,
                  color: isDarkMode
                      ? (isSecondary ? Colors.white70 : Colors.white)
                      : (isSecondary ? Colors.black54 : Colors.black87))),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: score / 10,
              minHeight: isSecondary ? 5 : 7,
              backgroundColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(
                  isSecondary ? _color.withOpacity(0.7) : _color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(score.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSecondary ? _color.withOpacity(0.8) : _color)),
        ),
      ],
    );
  }
}
