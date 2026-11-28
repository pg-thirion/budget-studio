import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.client,
    required this.onSignedIn,
  });

  final SupabaseClient client;
  final VoidCallback onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    setState(() {
      _signUp = signUp;
      _email.clear();
      _password.clear();
      _confirm.clear();
      _message = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = _signUp ? 'Creating account…' : 'Signing in…';
      _messageIsError = false;
    });
    try {
      if (_signUp) {
        final result = await widget.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: 'https://budget-studio-taupe.vercel.app',
        );
        if (!mounted) return;
        if (result.session != null) {
          widget.onSignedIn();
        } else {
          setState(() {
            _signUp = false;
            _confirm.clear();
            _password.clear();
            _message =
                'Check your email for a confirmation link. After confirming, return here and sign in.';
          });
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) widget.onSignedIn();
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to connect. Please try again.';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ledger.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: teal,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _signUp
                              ? 'Create your private budget workspace.'
                              : 'Sign in to your private budget.',
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email address.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          autofillHints: [
                            _signUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : _signUp && value.length < 12
                              ? 'Use at least 12 characters.'
                              : null,
                        ),
                        if (_signUp) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirm,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) => value != _password.text
                                ? 'Passwords do not match.'
                                : null,
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _messageIsError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            _busy
                                ? 'Please wait…'
                                : _signUp
                                ? 'Create account'
                                : 'Sign in',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => _setMode(!_signUp),
                          child: Text(
                            _signUp ? 'Back to sign in' : 'Create an account',
                          ),
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
    );
  }
}
