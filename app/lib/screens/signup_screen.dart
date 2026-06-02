import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/page_routes.dart';
import '../widgets/screen_background.dart';
import '../widgets/task2play_logo.dart';
import 'main_navigation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _auth = AuthService();
  bool _submitting = false;
  String? _error;
  bool _passwordHidden = true;
  String _avatar = adultAvatars.first;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _parentNameController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _auth.signUpParent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        parentDisplayName: _parentNameController.text.trim(),
        familyName: _familyNameController.text.trim(),
        avatar: _avatar,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        FadeUpRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanizeAuthError(e));
    } catch (e) {
      setState(() => _error = 'משהו השתבש: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanizeAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'האימייל הזה כבר רשום. אפשר להתחבר במקום.';
      case 'invalid-email':
        return 'כתובת אימייל לא תקינה.';
      case 'weak-password':
        return 'הסיסמה חלשה מדי. צריך לפחות 6 תווים.';
      case 'operation-not-allowed':
        return 'הרשמה באימייל לא מופעלת בפרויקט.';
      case 'network-request-failed':
        return 'אין חיבור לאינטרנט.';
      default:
        return 'שגיאה: ${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_forward,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppPalette.gold.withValues(alpha: 0.3),
                                AppPalette.gold.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                          const Task2PlayLogo(size: 88),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientText(
                      'יוצרים משפחה חדשה',
                      style: displayFont(
                        size: 26,
                        weight: FontWeight.w900,
                      ),
                      colors: AppPalette.heroGrad,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'הורה אחד נרשם, אחר כך מזמינים את כולם',
                      textAlign: TextAlign.center,
                      style: bodyFont(size: 13, color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    const FieldLabel('האווטר שלך'),
                    AvatarPicker(
                      selected: _avatar,
                      onSelect: (v) => setState(() => _avatar = v),
                      options: adultAvatars,
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('השם שלך'),
                    GameField(
                      controller: _parentNameController,
                      hint: 'למשל: אמא של דניאל',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'חובה' : null,
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('שם המשפחה'),
                    GameField(
                      controller: _familyNameController,
                      hint: 'למשל: משפחת לאופר',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'חובה' : null,
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('אימייל'),
                    GameField(
                      controller: _emailController,
                      hint: 'parent@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('סיסמה'),
                    GameField(
                      controller: _passwordController,
                      hint: 'לפחות 6 תווים',
                      obscureText: _passwordHidden,
                      textDirection: TextDirection.ltr,
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'לפחות 6 תווים' : null,
                      suffix: IconButton(
                        onPressed: () => setState(
                            () => _passwordHidden = !_passwordHidden),
                        icon: Icon(
                          _passwordHidden
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'יוצרים את המשפחה',
                      onTap: _submit,
                      loading: _submitting,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'חובה';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'אימייל לא תקין';
  }
}
