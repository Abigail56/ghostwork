// Port of frontend/src/app/(auth)/* — split panel on wide screens, same validation copy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../state/providers.dart';
import '../../components/logo.dart';
import '../../components/ui.dart';
import '../public/public_screens.dart';

String? validateEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email address.';

String? passwordProblems(String value) {
  if (value.length < 10) return 'Use at least 10 characters.';
  if (value.length > 128) return 'Use at most 128 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) return 'Include at least one letter and one number.';
  if (value.split('').toSet().length < 5) return 'This password is too repetitive.';
  return null;
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, this.description, required this.children});
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1024;
    // Web layout: logo pinned at the top, form vertically centered in the remaining space.
    final form = LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 64),
          child: Column(children: [
            if (!wide) ...[InkWell(onTap: () => context.go('/'), child: const Wordmark(size: 28)), const SizedBox(height: 32)],
            Expanded(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: wide ? c.maxHeight - 64 : (c.maxHeight - 160).clamp(0, double.infinity)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(title, style: GwText.title.copyWith(fontSize: 26, letterSpacing: -0.5)),
                      if (description != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(description!, style: GwText.body.copyWith(color: Gw.fgMuted))),
                      const SizedBox(height: 28),
                      ...children,
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: form),
              ])
            : form,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Gw.sidebar,
          border: Border(right: BorderSide(color: Gw.lineSubtle)),
          gradient: RadialGradient(center: Alignment(-1, -1), radius: 0.9, colors: [Color(0x2E8585FF), Gw.sidebar]),
        ),
        padding: const EdgeInsets.all(48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(onTap: () => context.go('/'), child: const Wordmark(size: 28)),
          const Spacer(),
          Text.rich(
            const TextSpan(children: [TextSpan(text: 'Your workflows.\n'), TextSpan(text: 'On autopilot.', style: TextStyle(color: Gw.violet))]),
            style: GwText.headline.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 420,
            child: Text('Connect your tools, orchestrate your work, and see every automation come to life in one connected workspace.',
                style: GwText.body.copyWith(fontSize: 15, color: Gw.fgSecondary, height: 1.6)),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 360,
            child: Column(children: [
              for (final (i, (icon, label, color, soft)) in const [
                (Icons.webhook, 'Webhook received', Gw.violet, Gw.violetSoft),
                (Icons.call_split, 'Priority is high', Gw.warning, Gw.warningSoft),
                (Icons.public, 'POST to incident API', Gw.cyan, Gw.cyanSoft),
              ].indexed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Gw.surface, borderRadius: BorderRadius.circular(Gw.rLg), border: Border.all(color: Gw.line)),
                  child: Row(children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 14, color: color)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: GwText.meta.copyWith(color: Gw.fg, fontWeight: FontWeight.w500))),
                    const Icon(Icons.check_circle_outline, size: 14, color: Gw.success),
                  ]),
                ),
                if (i < 2) Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(left: 26), width: 1, height: 20, color: Gw.cyan.withValues(alpha: 0.6))),
              ],
            ]),
          ),
          const Spacer(),
          Text('Let the repetitive work disappear.', style: GwText.meta),
        ]),
      );
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.error, this.autofill, this.onSubmitted, this.onChanged});
  final TextEditingController controller;
  final String? error;
  final String? autofill;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => GwInput(
        controller: widget.controller,
        obscure: !_visible,
        error: widget.error != null,
        autofillHints: widget.autofill == null ? null : [widget.autofill!],
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        suffix: GwIconButton(
          icon: _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          tooltip: _visible ? 'Hide password' : 'Show password',
          size: 32,
          onPressed: () => setState(() => _visible = !_visible),
        ),
      );
}

class PasswordStrength extends StatelessWidget {
  const PasswordStrength(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final checks = [
      value.length >= 10,
      RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'\d').hasMatch(value),
      value.split('').toSet().length >= 5,
      value.length >= 14,
    ];
    final score = checks.where((c) => c).length;
    const colors = [Gw.danger, Gw.danger, Gw.warning, Gw.success, Gw.success];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(color: i < score ? colors[score] : Gw.elevated, borderRadius: BorderRadius.circular(99)),
            ),
          ),
      ]),
    );
  }
}

/* ================================ Login ================================ */

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next, this.reset = false});
  final String? next;
  final bool reset;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _emailError = validateEmail(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
      _error = null;
    });
    if (_emailError != null || _passwordError != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final notice = auth is SignedOut ? auth.message : null;
    return AuthLayout(
      title: 'Welcome back',
      description: 'Sign in to manage your workflows.',
      children: [
        if (widget.reset) const Padding(padding: EdgeInsets.only(bottom: 16), child: GwAlert(tone: AlertTone.success, child: Text('Your password was reset. Sign in with your new password.'))),
        if (notice != null && _error == null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GwAlert(tone: AlertTone.info, child: Text(notice))),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GwAlert(child: Text(_error!))),
        AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GwField(
              label: 'Email',
              error: _emailError,
              child: GwInput(controller: _email, hint: 'you@company.com', keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], error: _emailError != null, semanticLabel: 'Email'),
            ),
            const SizedBox(height: 16),
            GwField(label: 'Password', error: _passwordError, child: PasswordField(controller: _password, error: _passwordError, autofill: AutofillHints.password, onSubmitted: (_) => _submit())),
          ]),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: GwLink('Forgot password?', onTap: () => context.go('/forgot-password'))),
        const SizedBox(height: 16),
        GwButton(label: 'Sign in', variant: GwVariant.primary, size: GwSize.lg, expand: true, loading: _busy, onPressed: _submit),
        const SizedBox(height: 24),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('New to GhostWork? ', style: GwText.body.copyWith(color: Gw.fgMuted)),
          GwLink('Create an account', style: GwText.body.copyWith(color: Gw.violet, fontWeight: FontWeight.w500), onTap: () => context.go('/register')),
        ]),
      ],
    );
  }
}

/* ================================ Register ================================ */

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  final Map<String, String?> _errors = {};
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _errors['name'] = _name.text.trim().isEmpty ? 'Enter your name.' : null;
      _errors['email'] = validateEmail(_email.text);
      _errors['password'] = passwordProblems(_password.text);
      _errors['terms'] = _accepted ? null : 'Please read and accept the Terms of Service to continue.';
      _error = null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).register(_name.text, _email.text, _password.text, acceptTerms: _accepted);
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        title: 'Create your account',
        description: 'Start automating in a couple of minutes.',
        children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GwAlert(child: Text(_error!))),
          GwField(label: 'Full name', error: _errors['name'], child: GwInput(controller: _name, hint: 'Ada Lovelace', autofillHints: const [AutofillHints.name], error: _errors['name'] != null, semanticLabel: 'Full name')),
          const SizedBox(height: 16),
          GwField(
            label: 'Work email',
            error: _errors['email'],
            child: GwInput(controller: _email, hint: 'you@company.com', keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], error: _errors['email'] != null, semanticLabel: 'Work email'),
          ),
          const SizedBox(height: 16),
          GwField(
            label: 'Password',
            error: _errors['password'],
            hint: const Text('At least 10 characters, with a letter and a number.'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PasswordField(controller: _password, error: _errors['password'], autofill: AutofillHints.newPassword, onChanged: (_) => setState(() {})),
              PasswordStrength(_password.text),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Terms of Service', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500))),
            GwLink('Open full page', icon: Icons.open_in_new, style: GwText.micro.copyWith(color: Gw.violet), onTap: () => context.push('/terms')),
          ]),
          const SizedBox(height: 10),
          Semantics(
            label: 'Terms of Service',
            child: Container(
              height: 208,
              decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
              child: Scrollbar(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: const TermsContent(compact: true))),
            ),
          ),
          const SizedBox(height: 10),
          GwCheckbox(
            value: _accepted,
            error: _errors['terms'] != null,
            onChanged: (v) => setState(() {
              _accepted = v;
              _errors['terms'] = null;
            }),
            label: Text.rich(TextSpan(style: GwText.meta.copyWith(color: Gw.fgSecondary, height: 1.5), children: const [
              TextSpan(text: 'I have read and agree to the '),
              TextSpan(text: 'Terms of Service', style: TextStyle(color: Gw.fg)),
              TextSpan(text: ' and the '),
              TextSpan(text: 'Privacy Policy', style: TextStyle(color: Gw.fg)),
              TextSpan(text: '.'),
            ])),
          ),
          if (_errors['terms'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errors['terms']!, style: GwText.meta.copyWith(color: Gw.danger))),
          const SizedBox(height: 16),
          GwButton(label: 'Create account', variant: GwVariant.primary, size: GwSize.lg, expand: true, loading: _busy, onPressed: _submit),
          const SizedBox(height: 24),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Already have an account? ', style: GwText.body.copyWith(color: Gw.fgMuted)),
            GwLink('Sign in', style: GwText.body.copyWith(color: Gw.violet, fontWeight: FontWeight.w500), onTap: () => context.go('/login')),
          ]),
        ],
      );
}

/* ================================ Password recovery ================================ */

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _emailError;
  String? _error;
  ({String message, bool emailConfigured})? _result;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => (_emailError = validateEmail(_email.text), _error = null));
    if (_emailError != null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiClientProvider).forgotPassword(_email.text.trim());
      setState(() => _result = r);
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        title: 'Reset your password',
        description: "Enter your account email and we'll send you a reset link.",
        children: [
          if (_result != null)
            _result!.emailConfigured
                ? GwCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.mark_email_read_outlined, size: 18, color: Gw.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Check your inbox', style: GwText.bodyMedium),
                          const SizedBox(height: 4),
                          Text('${_result!.message} The link expires in 30 minutes.', style: GwText.body.copyWith(color: Gw.fgMuted)),
                        ]),
                      ),
                    ]),
                  )
                : GwAlert(tone: AlertTone.warning, child: Text(_result!.message))
          else ...[
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GwAlert(child: Text(_error!))),
            GwField(
              label: 'Email',
              error: _emailError,
              child: GwInput(controller: _email, hint: 'you@company.com', keyboardType: TextInputType.emailAddress, error: _emailError != null, semanticLabel: 'Email', onSubmitted: (_) => _submit()),
            ),
            const SizedBox(height: 16),
            GwButton(label: 'Send reset link', variant: GwVariant.primary, size: GwSize.lg, expand: true, loading: _busy, onPressed: _submit),
          ],
          const SizedBox(height: 24),
          GwBackLink(label: 'Back to sign in', onTap: () => context.go('/login')),
        ],
      );
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _passwordError = passwordProblems(_password.text);
      _confirmError = _password.text == _confirm.text ? null : "Passwords don't match.";
      _error = null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).resetPassword(widget.token!, _password.text);
      if (mounted) context.go('/login?reset=1');
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.isEmpty) {
      return AuthLayout(title: 'Reset link missing', children: [
        const GwAlert(tone: AlertTone.warning, child: Text('This page needs the link from your reset email. Request a new one to continue.')),
        const SizedBox(height: 24),
        GwLink('Request a reset link', onTap: () => context.go('/forgot-password')),
      ]);
    }
    return AuthLayout(
      title: 'Choose a new password',
      description: "You'll be signed out of every device after the change.",
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GwAlert(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_error!), GwLink('Request a new link', onTap: () => context.go('/forgot-password'))])),
          ),
        GwField(
          label: 'New password',
          error: _passwordError,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PasswordField(controller: _password, error: _passwordError, autofill: AutofillHints.newPassword, onChanged: (_) => setState(() {})),
            PasswordStrength(_password.text),
          ]),
        ),
        const SizedBox(height: 16),
        GwField(label: 'Confirm password', error: _confirmError, child: PasswordField(controller: _confirm, error: _confirmError, autofill: AutofillHints.newPassword, onSubmitted: (_) => _submit())),
        const SizedBox(height: 16),
        GwButton(label: 'Update password', variant: GwVariant.primary, size: GwSize.lg, expand: true, loading: _busy, onPressed: _submit),
      ],
    );
  }
}
