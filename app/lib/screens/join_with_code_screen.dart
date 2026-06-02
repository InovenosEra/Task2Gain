import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/page_routes.dart';
import '../widgets/screen_background.dart';
import 'main_navigation.dart';

class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});
  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _submitting = false;
  bool _passwordHidden = true;
  String? _error;
  String _avatar = kidAvatars.first;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
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
      await _auth.signUpWithInvite(
        inviteCode: _codeController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        avatar: _avatar,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        FadeUpRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanize(e));
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'משהו השתבש: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanize(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'האימייל הזה כבר רשום. אפשר להתחבר.';
      case 'invalid-email':
        return 'אימייל לא תקין.';
      case 'weak-password':
        return 'הסיסמה חלשה. לפחות 6 תווים.';
      case 'network-request-failed':
        return 'אין חיבור.';
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
            child: Stack(
              children: [
                // Four fields + avatar don't fit one column in landscape, so
                // split them across two. Centred; scrolls only if squeezed.
                LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: c.maxHeight - 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GradientText(
                                  'מצטרפים למשפחה',
                                  style: displayFont(
                                      size: 24, weight: FontWeight.w900),
                                  colors: AppPalette.heroGrad,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _leftColumn()),
                                    const SizedBox(width: 20),
                                    Expanded(child: _rightColumn()),
                                  ],
                                ),
                              ],
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
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('האווטר שלך'),
          AvatarPicker(
            selected: _avatar,
            onSelect: (v) => setState(() => _avatar = v),
            options: kidAvatars,
          ),
          const SizedBox(height: 12),
          const FieldLabel('קוד ההזמנה'),
          GameField(
            controller: _codeController,
            hint: '6 ספרות',
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            maxLength: 6,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.length != 6) return 'הקוד הוא 6 ספרות';
              if (int.tryParse(s) == null) return 'רק ספרות';
              return null;
            },
          ),
          const SizedBox(height: 10),
          const FieldLabel('השם שלך'),
          GameField(
            controller: _nameController,
            hint: 'למשל: דניאל',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'חובה' : null,
          ),
        ],
      );

  Widget _rightColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('אימייל'),
          GameField(
            controller: _emailController,
            hint: 'kid@example.com',
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'חובה';
              final ok =
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
              return ok ? null : 'אימייל לא תקין';
            },
          ),
          const SizedBox(height: 10),
          const FieldLabel('סיסמה'),
          GameField(
            controller: _passwordController,
            hint: 'לפחות 6 תווים',
            textDirection: TextDirection.ltr,
            obscureText: _passwordHidden,
            validator: (v) =>
                (v == null || v.length < 6) ? 'לפחות 6 תווים' : null,
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _passwordHidden = !_passwordHidden),
              icon: Icon(
                _passwordHidden ? Icons.visibility : Icons.visibility_off,
                color: Colors.white54,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'מצטרף!',
            onTap: _submit,
            loading: _submitting,
          ),
        ],
      );
}
