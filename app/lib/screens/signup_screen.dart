import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/city_sky.dart';
import '../widgets/game_field.dart';
import '../widgets/page_routes.dart';
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
  File? _avatarFile;
  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (xfile == null) return;
      setState(() => _avatarFile = File(xfile.path));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא הצלחנו לפתוח את התמונה');
      }
    }
  }

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
        avatarFile: _avatarFile,
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
        backgroundColor: CitySky.skyTop,
        body: CitySkyBackground(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: CityCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'יוצרים משפחה חדשה',
                                    textAlign: TextAlign.center,
                                    style: cityFont(
                                        size: 23, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'הורה אחד נרשם, אחר כך מזמינים את כולם',
                                    textAlign: TextAlign.center,
                                    style: cityFont(
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        color: CitySky.inkSoft),
                                  ),
                                  const SizedBox(height: 12),
                                  AvatarPicker(
                                    light: true,
                                    bubbleSize: 46,
                                    selected: _avatar,
                                    photoFile: _avatarFile,
                                    onPickPhoto: _pickPhoto,
                                    onSelect: (v) => setState(() {
                                      _avatar = v;
                                      _avatarFile = null;
                                    }),
                                    options: adultAvatars,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const FieldLabel('השם שלך',
                                                light: true),
                                            GameField(
                                              light: true,
                                              controller: _parentNameController,
                                              hint: 'למשל: אמא של דניאל',
                                              validator: (v) => (v == null ||
                                                      v.trim().isEmpty)
                                                  ? 'חובה'
                                                  : null,
                                            ),
                                            const SizedBox(height: 10),
                                            const FieldLabel('שם המשפחה',
                                                light: true),
                                            GameField(
                                              light: true,
                                              controller: _familyNameController,
                                              hint: 'למשל: משפחת לאופר',
                                              validator: (v) => (v == null ||
                                                      v.trim().isEmpty)
                                                  ? 'חובה'
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const FieldLabel('אימייל',
                                                light: true),
                                            GameField(
                                              light: true,
                                              controller: _emailController,
                                              hint: 'parent@example.com',
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textDirection: TextDirection.ltr,
                                              validator: _validateEmail,
                                            ),
                                            const SizedBox(height: 10),
                                            const FieldLabel('סיסמה',
                                                light: true),
                                            GameField(
                                              light: true,
                                              controller: _passwordController,
                                              hint: 'לפחות 6 תווים',
                                              obscureText: _passwordHidden,
                                              textDirection: TextDirection.ltr,
                                              validator: (v) => (v == null ||
                                                      v.length < 6)
                                                  ? 'לפחות 6 תווים'
                                                  : null,
                                              suffix: IconButton(
                                                onPressed: () => setState(() =>
                                                    _passwordHidden =
                                                        !_passwordHidden),
                                                icon: Icon(
                                                  _passwordHidden
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: CitySky.inkSoft,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    ErrorBanner(message: _error!, light: true),
                                  ],
                                  const SizedBox(height: 14),
                                  CityButton(
                                    label: 'יוצרים את המשפחה',
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

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'חובה';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'אימייל לא תקין';
  }
}
