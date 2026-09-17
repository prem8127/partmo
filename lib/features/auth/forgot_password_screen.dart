import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';

/// 3-step forgot password flow:
///   Step 1 → Enter email  (sends OTP via Supabase)
///   Step 2 → Enter 6-digit OTP
///   Step 3 → Set new password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1;
  String _email = '';

  void _onEmailSent(String email) {
    setState(() {
      _email = email;
      _step = 2;
    });
  }

  void _onOtpVerified() {
    setState(() => _step = 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                34, MediaQuery.paddingOf(context).top + 40, 34, 26),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_step) {
                1 => _Step1Email(key: const ValueKey(1), onSent: _onEmailSent),
                2 => _Step2Otp(
                    key: const ValueKey(2),
                    email: _email,
                    onVerified: _onOtpVerified),
                _ => _Step3NewPassword(key: const ValueKey(3), email: _email),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Enter email
// ─────────────────────────────────────────────────────────────────────────────
class _Step1Email extends StatefulWidget {
  const _Step1Email({super.key, required this.onSent});
  final void Function(String email) onSent;

  @override
  State<_Step1Email> createState() => _Step1EmailState();
}

class _Step1EmailState extends State<_Step1Email> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _ctrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      widget.onSent(email);
    } catch (_) {
      setState(() =>
          _error = 'Could not send OTP. Please check the email and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: () => context.go('/login')),
        const SizedBox(height: 32),
        _IconBox(icon: Icons.lock_reset_outlined, color: AppPalette.cyan),
        const SizedBox(height: 20),
        const Text('Forgot Password',
            style: TextStyle(
                color: Color(0xFF222933),
                fontWeight: FontWeight.w900,
                fontSize: 28)),
        const SizedBox(height: 10),
        const Text(
          'Enter your registered email. We\'ll send a 6-digit OTP to reset your password.',
          style: TextStyle(color: Color(0xFF4E6070), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        const Text('EMAIL ADDRESS',
            style: TextStyle(
                color: Color(0xFF4E6070),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6)),
        const SizedBox(height: 9),
        SizedBox(
          height: 54,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'your@email.com',
              hintStyle:
                  const TextStyle(color: Color(0xFFB4BEC8), fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email,
                  size: 18, color: Color(0xFF9BA8B4)),
              filled: true,
              fillColor: const Color(0xFFE6EBF1),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide:
                      const BorderSide(color: AppPalette.cyan, width: 2)),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'SEND OTP',
          loading: _loading,
          onPressed: _send,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — Enter OTP
// ─────────────────────────────────────────────────────────────────────────────
class _Step2Otp extends StatefulWidget {
  const _Step2Otp({super.key, required this.email, required this.onVerified});
  final String email;
  final VoidCallback onVerified;

  @override
  State<_Step2Otp> createState() => _Step2OtpState();
}

class _Step2OtpState extends State<_Step2Otp> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otp,
        type: OtpType.recovery,
      );
      if (!mounted) return;
      widget.onVerified();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Invalid OTP. Please check and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _success = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);
      setState(() => _success = 'New OTP sent to ${widget.email}');
    } catch (_) {
      setState(() => _error = 'Could not resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: () => context.go('/login')),
        const SizedBox(height: 32),
        _IconBox(
            icon: Icons.mark_email_unread_outlined, color: AppPalette.cyan),
        const SizedBox(height: 20),
        const Text('Enter OTP',
            style: TextStyle(
                color: Color(0xFF222933),
                fontWeight: FontWeight.w900,
                fontSize: 28)),
        const SizedBox(height: 10),
        Text(
          'We sent a 6-digit OTP to\n${widget.email}',
          style: const TextStyle(
              color: Color(0xFF4E6070), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        // OTP boxes — same design as existing OtpVerifyScreen
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 5 ? 0 : 6),
                child: SizedBox(
                  height: 60,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: AppPalette.navy,
                    cursorHeight: 24,
                    style: const TextStyle(
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF071E33)),
                    strutStyle: const StrutStyle(
                        fontSize: 24, height: 1, forceStrutHeight: true),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFB8C5D1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFB8C5D1), width: 1.2)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppPalette.cyan, width: 2)),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && i < 5)
                        _focusNodes[i + 1].requestFocus();
                      if (val.isEmpty && i > 0)
                        _focusNodes[i - 1].requestFocus();
                      setState(() {});
                    },
                  ),
                ),
              ),
            );
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(message: _error!)
        ],
        if (_success != null) ...[
          const SizedBox(height: 14),
          _SuccessBox(message: _success!)
        ],
        const SizedBox(height: 28),
        _PrimaryButton(
            label: 'VERIFY OTP', loading: _loading, onPressed: _verify),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _resending ? null : _resend,
            child: _resending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text.rich(
                    TextSpan(
                      text: "Didn't receive a code? ",
                      style: TextStyle(color: Color(0xFF9CA8B4), fontSize: 13),
                      children: [
                        TextSpan(
                            text: 'Resend OTP',
                            style: TextStyle(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Set new password
// ─────────────────────────────────────────────────────────────────────────────
class _Step3NewPassword extends StatefulWidget {
  const _Step3NewPassword({super.key, required this.email});
  final String email;

  @override
  State<_Step3NewPassword> createState() => _Step3NewPasswordState();
}

class _Step3NewPasswordState extends State<_Step3NewPassword> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final pass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pass));
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _done = true;
        _loading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to update password. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(40)),
            child: const Icon(Icons.check_circle_outline,
                color: AppPalette.success, size: 48),
          ),
          const SizedBox(height: 28),
          const Text('Password Updated!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text(
            'Your password has been changed successfully.\nPlease log in with your new password.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Color(0xFF4E6070), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 36),
          _PrimaryButton(
              label: 'BACK TO LOGIN',
              loading: false,
              onPressed: () => context.go('/login')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: () => context.go('/login')),
        const SizedBox(height: 32),
        _IconBox(icon: Icons.lock_outline, color: AppPalette.navy),
        const SizedBox(height: 20),
        const Text('New Password',
            style: TextStyle(
                color: Color(0xFF222933),
                fontWeight: FontWeight.w900,
                fontSize: 28)),
        const SizedBox(height: 10),
        const Text('Choose a strong password for your account.',
            style:
                TextStyle(color: Color(0xFF4E6070), fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        _PasswordField(
            label: 'NEW PASSWORD',
            ctrl: _newCtrl,
            obscure: _obscure1,
            onToggle: () => setState(() => _obscure1 = !_obscure1)),
        const SizedBox(height: 20),
        _PasswordField(
            label: 'CONFIRM PASSWORD',
            ctrl: _confirmCtrl,
            obscure: _obscure2,
            onToggle: () => setState(() => _obscure2 = !_obscure2)),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(message: _error!)
        ],
        const SizedBox(height: 28),
        _PrimaryButton(
            label: 'UPDATE PASSWORD', loading: _loading, onPressed: _update),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: const Color(0xFFE6EBF1),
            borderRadius: BorderRadius.circular(5)),
        child: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: AppPalette.navy),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
          color: color.withOpacity(.15),
          borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 30, color: color),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.loading, required this.onPressed});
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(5)),
      child: Text(message,
          style: const TextStyle(
              color: AppPalette.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _SuccessBox extends StatelessWidget {
  const _SuccessBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFEEFFEE),
          borderRadius: BorderRadius.circular(5)),
      child: Text(message,
          style: const TextStyle(
              color: AppPalette.success,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField(
      {required this.label,
      required this.ctrl,
      required this.obscure,
      required this.onToggle});
  final String label;
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF4E6070),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6)),
        const SizedBox(height: 9),
        SizedBox(
          height: 54,
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle:
                  const TextStyle(color: Color(0xFFB4BEC8), fontSize: 13),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF9BA8B4),
                    size: 21),
              ),
              filled: true,
              fillColor: const Color(0xFFE6EBF1),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide:
                      const BorderSide(color: AppPalette.cyan, width: 2)),
            ),
          ),
        ),
      ],
    );
  }
}
