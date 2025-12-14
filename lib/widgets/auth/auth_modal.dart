import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

enum AuthMode { login, signup }
enum SignupStep { email, otp, password }

class AuthModal extends StatefulWidget {
  const AuthModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true, 
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: AuthModal(),
      ),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  // State
  AuthMode _authMode = AuthMode.signup; // Default to signup as requested implies new flow usage
  SignupStep _signupStep = SignupStep.email;
  bool _isLoading = false;
  
  // Timer
  Timer? _resendTimer;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }
  
  // --- AUTH METHODS ---

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/',
        authScreenLaunchMode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/',
        authScreenLaunchMode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // LOGIN: Password
  Future<void> _signInWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted && response.session != null) {
        Navigator.pop(context);
        _showSuccess('Welcome back!');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // SIGNUP: Step 1 - Send OTP
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      
      if (mounted) {
        setState(() {
          _signupStep = SignupStep.otp;
          _resendSeconds = 60;
          _startResendTimer();
        });
        _showSuccess('OTP sent! Check your email.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // SIGNUP: Step 2 - Verify OTP
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        token: otp,
        type: OtpType.email,
        email: _emailController.text.trim(),
      );
      
      if (mounted && response.session != null) {
        // OTP Verified -> Move to Set Password
        setState(() {
          _signupStep = SignupStep.password;
        });
      }
    } catch (e) {
      if (mounted) _showError('Invalid Code: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // SIGNUP: Step 3 - Set Password
  Future<void> _savePassword() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (mounted) {
        Navigator.pop(context); // Done!
        _showSuccess('Account created successfully!');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // --- HELPERS ---

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF4CAF50)),
    );
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final targetWidth = screenWidth * 0.8;
    final maxTargetHeight = screenHeight * 0.8;
    final finalWidth = targetWidth > 450.0 ? 450.0 : targetWidth;

    return Center(
      child: Container(
        width: finalWidth,
        constraints: BoxConstraints(maxHeight: maxTargetHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final bool isCompact = availableHeight < 600;
            final bool isVeryCompact = availableHeight < 450;
            final double padding = isCompact ? 16 : 24;
            
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Toggle or Title
                      // Hiding Toggle if in OTP/Password steps to avoid confusion
                      if (_signupStep == SignupStep.email) 
                        _buildAuthToggle(isCompact),
                      
                      SizedBox(height: isCompact ? 16 : 24),
                      
                      // Body
                      Flexible(
                        child: SingleChildScrollView( // Allow scroll if content needs it, though we try to fit
                           child: _buildCurrentView(isCompact, isVeryCompact),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Close Button
                Positioned(
                   right: 4,
                   top: 4,
                   child: IconButton(
                     onPressed: () {
                         // Back logic for multi-step
                         if (_authMode == AuthMode.signup && _signupStep != SignupStep.email) {
                           setState(() {
                             // Go back one step
                             if (_signupStep == SignupStep.password) _signupStep = SignupStep.otp;
                             else if (_signupStep == SignupStep.otp) {
                               _signupStep = SignupStep.email;
                               _resendTimer?.cancel();
                             }
                           });
                         } else {
                           Navigator.pop(context);
                         }
                     },
                     icon: Icon(
                       (_authMode == AuthMode.signup && _signupStep != SignupStep.email) 
                         ? Icons.arrow_back 
                         : Icons.close, 
                       color: Colors.black45
                     ),
                     splashRadius: 20,
                   ),
                ),
                
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
                      child: const Center(child: CircularProgressIndicator(color: Colors.black)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  // --- SUB-VIEWS ---
  
  Widget _buildAuthToggle(bool isCompact) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          _buildToggleItem('Log In', AuthMode.login),
          _buildToggleItem('Sign Up', AuthMode.signup),
        ],
      ),
    );
  }
  
  Widget _buildToggleItem(String label, AuthMode mode) {
    final isActive = _authMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _authMode = mode),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFFE50914) : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(bool isCompact, bool isVeryCompact) {
    if (_authMode == AuthMode.login) {
      return _buildLoginPasswordView(isCompact, isVeryCompact);
    } else {
      switch (_signupStep) {
        case SignupStep.email:
          return _buildSignupEmailView(isCompact, isVeryCompact);
        case SignupStep.otp:
          return _buildSignupOtpView(isCompact, isVeryCompact);
        case SignupStep.password:
          return _buildSignupSetPasswordView(isCompact, isVeryCompact);
      }
    }
  }

  // 1. LOG IN (Email + Password)
  Widget _buildLoginPasswordView(bool isCompact, bool vCompact) {
    final hasInput = _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;
    return Column(
      children: [
         _buildLogo(isCompact, vCompact),
         SizedBox(height: isCompact ? 12 : 24),
         
         // Email
         _buildTextField(_emailController, 'Email', TextInputType.emailAddress, isCompact),
         SizedBox(height: isCompact ? 8 : 12),
         
         // Password
         _buildTextField(_passwordController, 'Password', TextInputType.visiblePassword, isCompact, isPassword: true),
         
         SizedBox(height: isCompact ? 16 : 24),
         
         _buildButton(
           label: 'Log In', 
           iconWidget: null, 
           onTap: hasInput ? _signInWithPassword : () {}, 
           isCompact: isCompact, 
           textColor: hasInput ? Colors.white : Colors.black38, 
           hasBorder: false, 
           backgroundColor: hasInput ? const Color(0xFFE50914) : Colors.grey[300]!
         ),

         SizedBox(height: isCompact ? 16 : 24),
         _buildSocialButtons(isCompact),
      ],
    );
  }

  // 2. SIGN UP: STEP 1 (Email)
  Widget _buildSignupEmailView(bool isCompact, bool vCompact) {
    final hasInput = _emailController.text.isNotEmpty;
    // Exactly like the old "Login with Email" but for Sending Code
    return Column(
      children: [
        _buildLogo(isCompact, vCompact),
        SizedBox(height: isCompact ? 12 : 24),
        
        Text(
          'Create an account',
          style: TextStyle(fontSize: isCompact ? 20 : 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        
        _buildTextField(_emailController, 'Email', TextInputType.emailAddress, isCompact),
        
        SizedBox(height: isCompact ? 16 : 24),
         
        _buildButton(
           label: 'Continue with Email', 
           iconWidget: null, 
           onTap: hasInput ? _sendOtp : () {}, 
           isCompact: isCompact, 
           textColor: hasInput ? Colors.white : Colors.black38, 
           hasBorder: false, 
           backgroundColor: hasInput ? const Color(0xFFE50914) : Colors.grey[300]!
         ),
         
         SizedBox(height: isCompact ? 16 : 24),
         _buildSocialButtons(isCompact),
      ],
    );
  }

  // 3. SIGN UP: STEP 2 (OTP)
  Widget _buildSignupOtpView(bool isCompact, bool vCompact) {
    return Column(
      children: [
        _buildLogo(isCompact, vCompact),
        SizedBox(height: isCompact ? 16 : 24),
        
        Text('Verify your email', style: TextStyle(fontSize: isCompact ? 20 : 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Sent code to ${_emailController.text}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        SizedBox(height: isCompact ? 24 : 32),
        
        // Flexible OTP Input Box
        SizedBox(
          width: 280,
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter Code',
              hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 1, fontSize: 16),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black)),
            ),
            autofocus: true,
            onChanged: (val) => setState((){}), // Update state for button color if needed
          ),
        ),
        
        SizedBox(height: isCompact ? 16 : 24),

        // Manual Verify Button
        _buildButton(
           label: 'Verify', 
           iconWidget: null, 
           onTap: _otpController.text.trim().isNotEmpty ? _verifyOtp : () {}, 
           isCompact: isCompact, 
           textColor: _otpController.text.trim().isNotEmpty ? Colors.white : Colors.black38, 
           hasBorder: false, 
           backgroundColor: _otpController.text.trim().isNotEmpty ? const Color(0xFFE50914) : Colors.grey[300]!
         ),
        
        SizedBox(height: isCompact ? 16 : 24),
        _buildResendTimer(),
      ],
    );
  }

  // 4. SIGN UP: STEP 3 (Set Password)
  Widget _buildSignupSetPasswordView(bool isCompact, bool vCompact) {
    final hasInput = _passwordController.text.isNotEmpty;
    return Column(
      children: [
        _buildLogo(isCompact, vCompact),
        SizedBox(height: isCompact ? 16 : 24),
        
        Text('Set a Password', style: TextStyle(fontSize: isCompact ? 20 : 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Secure your account for future logins', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        SizedBox(height: isCompact ? 24 : 32),
        
        _buildTextField(_passwordController, 'Create Password', TextInputType.visiblePassword, isCompact, isPassword: true),
        
        SizedBox(height: isCompact ? 24 : 32),
        
        _buildButton(
           label: 'Save Password', 
           iconWidget: null, 
           onTap: hasInput ? _savePassword : () {}, 
           isCompact: isCompact, 
           textColor: hasInput ? Colors.white : Colors.black38, 
           hasBorder: false, 
           backgroundColor: hasInput ? const Color(0xFFE50914) : Colors.grey[300]!
         ),
      ],
    );
  }

  // --- COMMON WIDGETS ---
  
  Widget _buildLogo(bool isCompact, bool vCompact) {
    if (vCompact) return SizedBox.shrink();
    return SvgPicture.asset(
      'assets/svg/logo/popuplogo.svg',
      height: isCompact ? 32 : 48,
      width: isCompact ? 32 : 48,
    );
  }
  
  Widget _buildTextField(TextEditingController controller, String hint, TextInputType type, bool isCompact, {bool isPassword = false}) {
    return SizedBox(
      height: isCompact ? 40 : 48,
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: isPassword,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: isCompact ? 14 : 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: isCompact ? 14 : 16),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        ),
      ),
    );
  }
  
  Widget _buildSocialButtons(bool isCompact) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
          ],
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildButton(
          label: 'with Google',
          iconWidget: SvgPicture.asset('assets/svg/logo/G.svg', height: isCompact ? 18 : 22, width: isCompact ? 18 : 22),
          onTap: _signInWithGoogle,
          isCompact: isCompact,
          textColor: Colors.black,
          hasBorder: true,
          backgroundColor: Colors.white,
        ),
        SizedBox(height: isCompact ? 8 : 12),
        _buildButton(
          label: 'with Apple',
          iconWidget: Icon(FontAwesomeIcons.apple, size: isCompact ? 18 : 22, color: Colors.white),
          onTap: _signInWithApple,
          isCompact: isCompact,
          textColor: Colors.white,
          hasBorder: false,
          backgroundColor: Colors.black,
        ),
      ],
    );
  }
  
  Widget _buildResendTimer() {
    return GestureDetector(
      onTap: _resendSeconds == 0 ? _sendOtp : null,
      child: Text(
        _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend Code',
        style: TextStyle(color: _resendSeconds > 0 ? Colors.grey : Colors.blue, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Widget? iconWidget,
    required VoidCallback onTap,
    required bool isCompact,
    required Color textColor,
    required bool hasBorder,
    required Color backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: isCompact ? 40 : 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: hasBorder ? Border.all(color: Colors.grey[300]!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null) ...[iconWidget, SizedBox(width: 10)],
            Text(label, style: TextStyle(fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }
}
