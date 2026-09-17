import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (!mounted) return;
      setState(() {
        _success = true;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: _success ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: const Color(0xFFE8F8F5),
              borderRadius: BorderRadius.circular(40)),
          child: const Icon(Icons.check_circle_outline,
              color: AppPalette.cyan, size: 48),
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
          'Your password has been successfully updated.\nYou can now log in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF4E6070), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => context.go('/login'),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
            child: const Text('BACK TO LOGIN',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppPalette.navy,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x30073B63),
                    blurRadius: 12,
                    offset: Offset(0, 5))
              ],
            ),
            child: const Icon(Icons.lock_reset, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          const Text('PARTMO',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2)),
        ]),
        const SizedBox(height: 48),
        const Text('Set New Password',
            style: TextStyle(
                color: Color(0xFF172635),
                fontSize: 30,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text('Choose a strong password for your account.',
            style: TextStyle(
                color: Color(0xFF4E6070), fontSize: 13, height: 1.45)),
        const SizedBox(height: 36),
        _passField('NEW PASSWORD', _newPassCtrl, _obscure1,
            () => setState(() => _obscure1 = !_obscure1)),
        const SizedBox(height: 20),
        _passField('CONFIRM PASSWORD', _confirmPassCtrl, _obscure2,
            () => setState(() => _obscure2 = !_obscure2)),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            onPressed: _loading ? null : _updatePassword,
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
                : const Text('UPDATE PASSWORD',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
          ),
        ),
      ],
    );
  }

  Widget _passField(String label, TextEditingController ctrl, bool obscure,
      VoidCallback onToggle) {
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
                  borderSide: const BorderSide(color: AppPalette.cyan)),
            ),
          ),
        ),
      ],
    );
  }
}
