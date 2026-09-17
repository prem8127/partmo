import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
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
    final otp = _otp;
    if (otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.email,
      );
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Verification failed. Please check your OTP.');
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
      await SupabaseService.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: false,
      );
      setState(() => _success = 'New OTP sent to ${widget.email}');
    } catch (e) {
      setState(() => _error = 'Could not resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go('/login'),
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
                const SizedBox(height: 32),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: AppPalette.cyan.withOpacity(.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 30, color: AppPalette.cyan),
                ),
                const SizedBox(height: 20),
                const Text('Verify Your Email',
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
                const SizedBox(height: 28),

                // OTP boxes
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
                                fontSize: 24,
                                height: 1,
                                forceStrutHeight: true),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFB8C5D1))),
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
                              if (val.isNotEmpty && i < 5) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (val.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
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
                if (_success != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEFFEE),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(_success!,
                        style: const TextStyle(
                            color: AppPalette.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _verify,
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
                        : const Text('VERIFY & ACTIVATE',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                  ),
                ),
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
                              style: TextStyle(
                                  color: Color(0xFF9CA8B4), fontSize: 13),
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
            ),
          ),
        ),
      ),
    );
  }
}
