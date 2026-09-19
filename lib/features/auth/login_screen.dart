import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _showForgotPasswordDialog() async {
    final forgotEmailCtrl = TextEditingController();
    bool sending = false;
    String? dialogError;
    bool sent = false;

    await showDialog(
      context: context,
      barrierDismissible: !sending,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF8FAFD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Reset Password',
            style: TextStyle(
              color: Color(0xFF172635),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!sent) ...[
                const Text(
                  'Enter your registered email address. We\'ll send you a link to reset your password.',
                  style: TextStyle(
                    color: Color(0xFF4E6070),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: forgotEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB4BEC8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.alternate_email,
                      size: 18,
                      color: Color(0xFF9BA8B4),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFE6EBF1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: AppPalette.cyan),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(
                        color: AppPalette.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppPalette.cyan,
                  size: 48,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Reset email sent! Check your inbox and follow the link to set a new password.',
                  style: TextStyle(
                    color: Color(0xFF4E6070),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
          actions: sent
              ? [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: sending ? null : () => Navigator.pop(ctx),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFF7A8999),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final email = forgotEmailCtrl.text.trim();
                            if (email.isEmpty) {
                              setDialogState(
                                () => dialogError =
                                    'Please enter your email address.',
                              );
                              return;
                            }
                            setDialogState(() {
                              sending = true;
                              dialogError = null;
                            });
                            try {
                              await SupabaseService.resetPassword(email: email);
                              setDialogState(() {
                                sent = true;
                                sending = false;
                              });
                            } catch (e) {
                              setDialogState(() {
                                sending = false;
                                dialogError =
                                    'Failed to send reset email. Check the address and try again.';
                              });
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SEND RESET LINK',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ],
        ),
      ),
    );
    forgotEmailCtrl.dispose();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.signIn(email: email, password: pass);
      if (!mounted) return;
      if (SupabaseService.isAdmin) {
        context.go('/admin');
      } else {
        // Check for return route (e.g. from cart auth guard)
        final returnTo = GoRouterState.of(
          context,
        ).uri.queryParameters['return'];
        context.go(returnTo ?? '/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFFF8FAFD),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: .45,
                    child: CustomPaint(painter: _LoginBlueprintPainter()),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(34, 38, 34, 26),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _HeaderLogo(),
                          const SizedBox(width: 10),
                          Text(
                            'PARTMO',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppPalette.navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: -.2,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 42),
                      Text(
                        'Welcome Back.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF222933),
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                              height: .9,
                            ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Access your engineering dossier and order\nhistory.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF4E6070),
                          height: 1.45,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 38),
                      _AuthField(
                        label: 'EMAIL ADDRESS',
                        hint: 'e.g. engineer@precision.com',
                        icon: Icons.alternate_email,
                        controller: _emailCtrl,
                      ),
                      const SizedBox(height: 20),
                      _AuthField(
                        label: 'ACCESS PASSWORD',
                        hint: '********',
                        icon: Icons.lock_outline,
                        obscure: true,
                        controller: _passCtrl,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.navy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppPalette.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            elevation: 6,
                            shadowColor: const Color(0x52073B63),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'NEW MEMBER?',
                        style: TextStyle(
                          color: Color(0xFF9CA8B4),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => context.push('/signup'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.cyan,
                            foregroundColor: AppPalette.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'CREATE NEW ACCOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 70),
                      const Row(
                        children: [
                          Expanded(
                            child: _PrecisionTile(
                              label: 'OEM PRECISION',
                              icon: Icons.blur_on,
                            ),
                          ),
                          SizedBox(width: 42),
                          Expanded(
                            child: _PrecisionTile(
                              label: 'VERIFIED STOCK',
                              icon: Icons.trip_origin,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 64),
                      const Text(
                        '(c) 2026 PartMo Dossier Access. All Rights Reserved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA8B4),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text('PRIVACY POLICY', style: _footerLinkStyle),
                          Text(
                            '*',
                            style: TextStyle(
                              color: Color(0xFF9CA8B4),
                              fontSize: 9,
                            ),
                          ),
                          Text('TERMS OF SERVICE', style: _footerLinkStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _footerLinkStyle = TextStyle(
  color: Color(0xFF7F8C98),
  fontSize: 9,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
);

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30073B63),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.tune, color: Colors.white, size: 25),
    );
  }
}

// ── Stateful so it can toggle obscureText independently ──────────────────────
class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
  });
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
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
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 54,
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            keyboardType: widget.obscure
                ? TextInputType.visiblePassword
                : TextInputType.emailAddress,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: Color(0xFFB4BEC8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              // Show toggle icon for password fields, static icon otherwise
              suffixIcon: widget.obscure
                  ? GestureDetector(
                      onTap: () => setState(() => _obscureText = !_obscureText),
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9BA8B4),
                        size: 21,
                      ),
                    )
                  : Icon(widget.icon, color: const Color(0xFF9BA8B4), size: 21),
              filled: true,
              fillColor: const Color(0xFFE6EBF1),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: AppPalette.cyan),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrecisionTile extends StatelessWidget {
  const _PrecisionTile({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 136,
          decoration: BoxDecoration(
            color: const Color(0xFF244847),
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _TileGridPainter())),
              Center(
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(.34),
                  size: 72,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF263746),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LoginBlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAF0F5)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 30)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    for (var x = 0.0; x < size.width; x += 30)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    final glow = Paint()..color = const Color(0xFFF1F5F8);
    canvas.drawCircle(Offset(size.width * .5, size.height * .58), 88, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TileGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.12)
      ..strokeWidth = .8;
    for (var i = 12.0; i < size.width; i += 18)
      canvas.drawLine(Offset(i, 10), Offset(i, size.height - 10), paint);
    for (var i = 12.0; i < size.height; i += 18)
      canvas.drawLine(Offset(10, i), Offset(size.width - 10, i), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
