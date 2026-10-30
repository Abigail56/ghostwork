import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/providers.dart';
import '../widgets/logo.dart';

String? validateEmail(String? v) =>
    v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Enter a valid email address.' : null;

String? validateNewPassword(String? v) {
  final value = v ?? '';
  if (value.length < 10) return 'Use at least 10 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) return 'Include a letter and a number.';
  if (value.split('').toSet().length < 5) return 'This password is too repetitive.';
  return null;
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: Alignment.centerLeft, child: Wordmark()),
                  const SizedBox(height: 32),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Gw.fgMuted)),
                  const SizedBox(height: 24),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Gw.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Gw.danger.withValues(alpha: 0.3)),
        ),
        child: Text(message, style: const TextStyle(color: Color(0xFFFFB3B8))),
      );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
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
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to monitor your workflows.',
      children: [
        if (_error != null) _ErrorBanner(_error!) else if (notice != null) _ErrorBanner(notice),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Sign in'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(onPressed: () => context.go('/register'), child: const Text('New to GhostWork? Create an account')),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _summary = [
    "You're responsible for your account and for what your workflows do.",
    "Only automate systems, accounts and data you're allowed to use.",
    'Your workflows and data belong to you. We use them only to run the service.',
    "GhostWork is in early access: it's free, and it comes without uptime guarantees.",
    'You can delete your account and all its data at any time.',
  ];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _termsError = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _termsError = !_accepted);
    if (!valid || !_accepted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).register(_name.text, _email.text, _password.text, acceptTerms: _accepted);
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Create your account',
        subtitle: 'Start automating in a couple of minutes.',
        children: [
          if (_error != null) _ErrorBanner(_error!),
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 10 characters, with a letter and a number.'),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Gw.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Gw.violet.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Terms of Service — the short version', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final line in _summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  $line', style: const TextStyle(fontSize: 13, color: Gw.fgSecondary)),
                ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => launchUrl(Uri.parse('$webAppUrl/terms'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Read the full Terms of Service'),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() {
              _accepted = v ?? false;
              _termsError = false;
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text.rich(TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Gw.fgSecondary),
              children: [
                const TextSpan(text: 'I have read and agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(color: Gw.fg, decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(Uri.parse('$webAppUrl/terms'), mode: LaunchMode.externalApplication),
                ),
                const TextSpan(text: ' (version $termsVersion) and the Privacy Policy.'),
              ],
            )),
            subtitle: _termsError
                ? const Text('Please read and accept the Terms of Service to continue.', style: TextStyle(color: Gw.danger))
                : null,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Create account'),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign in')),
        ],
      );
}
