import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/city_sky.dart';
import '../widgets/game_field.dart';
import '../widgets/page_routes.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _submitting = false;
  bool _passwordHidden = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await _auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        FadeUpRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanize(e));
    } catch (e) {
      setState(() => _error = 'משהו השתבש: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanize(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'אימייל או סיסמה שגויים.';
      case 'invalid-email':
        return 'כתובת אימייל לא תקינה.';
      case 'user-disabled':
        return 'החשבון הזה הושבת.';
      case 'too-many-requests':
        return 'יותר מדי ניסיונות. נסה שוב בעוד דקה.';
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
        backgroundColor: CitySky.skyTop,
        body: CitySkyBackground(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: CityCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'ברוך שובך',
                                    textAlign: TextAlign.center,
                                    style: cityFont(
                                        size: 23, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'מתחברים לחשבון הקיים',
                                    textAlign: TextAlign.center,
                                    style: cityFont(
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        color: CitySky.inkSoft),
                                  ),
                                  const SizedBox(height: 16),
                                  const FieldLabel('אימייל', light: true),
                                  GameField(
                                    light: true,
                                    controller: _emailController,
                                    hint: 'parent@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    textDirection: TextDirection.ltr,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'חובה';
                                      }
                                      final ok = RegExp(
                                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(v.trim());
                                      return ok ? null : 'אימייל לא תקין';
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  const FieldLabel('סיסמה', light: true),
                                  GameField(
                                    light: true,
                                    controller: _passwordController,
                                    hint: 'הסיסמה שלך',
                                    textDirection: TextDirection.ltr,
                                    obscureText: _passwordHidden,
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'חובה'
                                        : null,
                                    suffix: IconButton(
                                      onPressed: () => setState(() =>
                                          _passwordHidden = !_passwordHidden),
                                      icon: Icon(
                                        _passwordHidden
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: CitySky.inkSoft,
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    ErrorBanner(message: _error!, light: true),
                                  ],
                                  const SizedBox(height: 18),
                                  CityButton(
                                    label: 'התחבר',
                                    onTap: _submit,
                                    loading: _submitting,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 4,
                  child: CityBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
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
