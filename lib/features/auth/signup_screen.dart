import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    final strongPassword = pass.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(pass) &&
        RegExp(r'[A-Z]').hasMatch(pass) &&
        RegExp(r'[0-9]').hasMatch(pass) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pass);
    if (!strongPassword) {
      setState(() => _error =
          'Use at least 8 characters with uppercase, lowercase, number and special character.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.signUp(
          email: email, password: pass, fullName: name);
      if (!mounted) return;
      context.push('/otp-verify', extra: {'email': email});
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Signup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                    opacity: .35, child: CustomPaint(painter: _GridPainter())),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    34, MediaQuery.paddingOf(context).top + 20, 34, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE6EBF1),
                            borderRadius: BorderRadius.circular(5)),
                        child: const Icon(Icons.arrow_back_ios_new,
                            size: 16, color: AppPalette.navy),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppPalette.navy,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.tune,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text('PARTMO',
                            style: TextStyle(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('Create Account.',
                        style: TextStyle(
                            color: Color(0xFF222933),
                            fontWeight: FontWeight.w900,
                            fontSize: 30)),
                    const SizedBox(height: 10),
                    const Text(
                      'Register to access genuine spare parts\nand track your orders.',
                      style: TextStyle(
                          color: Color(0xFF4E6070),
                          height: 1.45,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 32),
                    _Field(
                        label: 'FULL NAME',
                        hint: 'e.g. Rajesh Kumar',
                        icon: Icons.person_outline,
                        controller: _nameCtrl),
                    const SizedBox(height: 18),
                    _Field(
                        label: 'EMAIL ADDRESS',
                        hint: 'e.g. rajesh@gmail.com',
                        icon: Icons.alternate_email,
                        controller: _emailCtrl,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 18),
                    _Field(
                        label: 'PASSWORD',
                        hint: '8+ chars: Aa, number & symbol',
                        icon: Icons.lock_outline,
                        controller: _passCtrl,
                        obscure: true),
                    const SizedBox(height: 18),
                    _Field(
                        label: 'CONFIRM PASSWORD',
                        hint: 'Re-enter password',
                        icon: Icons.lock_outline,
                        controller: _confirmCtrl,
                        obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppPalette.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _signup,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.navy,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('CREATE ACCOUNT',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                                color: Color(0xFF9CA8B4), fontSize: 12),
                            children: [
                              TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                      color: AppPalette.navy,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FD),
                        borderRadius: BorderRadius.circular(5),
                        border:
                            Border.all(color: AppPalette.cyan.withOpacity(.4)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: AppPalette.cyan),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A 6-digit OTP will be sent to your email. Enter it on the next screen to activate your account.',
                              style: TextStyle(
                                  color: Color(0xFF3A6080),
                                  fontSize: 11,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stateful so each password field toggles independently ────────────────────
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.type = TextInputType.text,
  });
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType type;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
              color: Color(0xFF4E6070),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            keyboardType: widget.type,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFB4BEC8), fontSize: 13),
              // Toggle eye icon for password fields, static icon for others
              suffixIcon: widget.obscure
                  ? GestureDetector(
                      onTap: () => setState(() => _obscureText = !_obscureText),
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9BA8B4),
                        size: 20,
                      ),
                    )
                  : Icon(widget.icon, color: const Color(0xFF9BA8B4), size: 20),
              filled: true,
              fillColor: const Color(0xFFE6EBF1),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppPalette.cyan)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAF0F5)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = 0.0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
