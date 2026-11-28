import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'budget_home.dart';
import 'cloud.dart';
import 'sign_in.dart';
import 'workspace.dart';

const _cloudUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://bzceexgpkudfpptjhugi.supabase.co',
);
const _publicKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_ZU6M87IPBQ4mskX-n8PbBw_Ta2hU2KP',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _cloudUrl, publishableKey: _publicKey);
  final preferences = await SharedPreferences.getInstance();
  runApp(LedgerApp(client: Supabase.instance.client, preferences: preferences));
}

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key, required this.client, required this.preferences});

  final SupabaseClient client;
  final SharedPreferences preferences;

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late final StreamSubscription<AuthState> _auth;
  late String? _user;
  late ThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _user = widget.client.auth.currentUser?.id;
    _mode = switch (widget.preferences.getString('ledger-theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _auth = widget.client.auth.onAuthStateChange.listen(
      (_) => _refreshSession(),
      onError: (Object _) {},
    );
  }

  void _refreshSession() {
    final user = widget.client.auth.currentUser?.id;
    if (mounted && _user != user) setState(() => _user = user);
  }

  void _toggleTheme() {
    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final dark =
        _mode == ThemeMode.dark || (_mode == ThemeMode.system && systemDark);
    setState(() => _mode = dark ? ThemeMode.light : ThemeMode.dark);
    unawaited(widget.preferences.setString('ledger-theme', _mode.name));
  }

  @override
  void dispose() {
    unawaited(_auth.cancel());
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xff101826) : const Color(0xfff4f6f9);
    final panel = dark ? const Color(0xff192638) : Colors.white;
    final line = dark ? const Color(0xff304056) : const Color(0xffe0e7ee);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff166b64),
      brightness: brightness,
      primary: dark ? const Color(0xff77ddc8) : const Color(0xff166b64),
      surface: panel,
      outlineVariant: line,
      onSurface: dark ? const Color(0xffedf2fa) : const Color(0xff17253a),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: line),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: line),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: panel),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: border,
        enabledBorder: border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ledger',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: _mode,
    debugShowCheckedModeBanner: false,
    home: _user == null
        ? SignInScreen(client: widget.client, onSignedIn: _refreshSession)
        : _CloudBudget(
            key: ValueKey(_user),
            client: widget.client,
            user: _user!,
            onTheme: _toggleTheme,
          ),
  );
}

class _CloudBudget extends StatefulWidget {
  const _CloudBudget({
    super.key,
    required this.client,
    required this.user,
    required this.onTheme,
  });

  final SupabaseClient client;
  final String user;
  final VoidCallback onTheme;

  @override
  State<_CloudBudget> createState() => _CloudBudgetState();
}

class _CloudBudgetState extends State<_CloudBudget>
    with WidgetsBindingObserver {
  late final _cloud = CloudWorkspace(widget.client);
  Workspace? _workspace;
  int? _revision;
  String? _saved;
  String? _error;
  bool _conflict = false;
  bool _loading = true;
  bool _signingOut = false;
  Timer? _timer;
  Future<void>? _saving;

  String? get _current =>
      _workspace == null ? null : jsonEncode(_workspace!.data);
  bool get _dirty => _workspace != null && _saved != _current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.resumed) {
      unawaited(_save());
    }
  }

  Future<void> _load() async {
    _timer?.cancel();
    if (_saving != null) await _saving;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _cloud.load(widget.user);
      final month = monthKey(ledgerToday());
      final workspace = row.snapshot == null
          ? Workspace.empty(month)
          : Workspace.parse(row.snapshot);
      workspace.goals;
      final saved = jsonEncode(workspace.data);
      workspace.month(month);
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _revision = row.revision;
        _saved = saved;
        _conflict = false;
      });
    } on FormatException {
      if (mounted) {
        setState(
          () => _error =
              'The cloud budget is invalid. Your data was left intact.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load your budget. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_error == null && _revision != null && _dirty) _schedule();
      }
    }
  }

  void _schedule() {
    if (!mounted) return;
    setState(() {});
    _timer?.cancel();
    if (!_conflict) {
      _timer = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_save()),
      );
    }
  }

  Future<void> _save() {
    _timer?.cancel();
    final saving = _saving;
    if (saving != null) return saving;
    if (!_dirty || _conflict || _loading || !mounted) return Future.value();
    final future = Future<void>.microtask(_saveChanges);
    setState(() {
      _saving = future;
      _error = null;
    });
    return future;
  }

  Future<void> _saveChanges() async {
    try {
      while (mounted &&
          _dirty &&
          widget.client.auth.currentUser?.id == widget.user) {
        final text = _current!;
        final snapshot = Workspace.parse(jsonDecode(text)).data;
        _revision = await _cloud.save(widget.user, snapshot, _revision);
        _saved = text;
      }
    } on WorkspaceConflict {
      _conflict = true;
      _error = 'Cloud conflict. Export a backup, then reload the cloud budget.';
    } on FormatException {
      _error = 'Save failed. Check your budget entries.';
    } catch (_) {
      _error = 'Save failed. Check your connection and retry.';
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<bool> _discard(String title, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text(
            'Your changes haven’t saved. Export a backup if you want to keep them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _reload() async {
    if (_saving != null) await _saving;
    if (!mounted || _loading) return;
    if (_dirty && !await _discard('Reload cloud budget?', 'Reload')) return;
    if (mounted) await _load();
  }

  Future<void> _signOut() async {
    if (_signingOut || _loading) return;
    _signingOut = true;
    try {
      await _save();
      if (!mounted) return;
      if (_dirty && !await _discard('Sign out?', 'Sign out')) return;
      if (mounted) await widget.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
        );
      }
    } finally {
      _signingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspace;
    if (workspace == null || _loading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? 'Could not load your budget.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: _signOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    return BudgetHome(
      key: ObjectKey(workspace),
      workspace: workspace,
      status:
          _error ??
          (_saving != null
              ? 'Saving to cloud…'
              : _dirty
              ? 'Changes pending'
              : _revision == null
              ? 'Ready to budget'
              : 'Saved to cloud'),
      onChanged: _schedule,
      onSave: _save,
      onReload: _reload,
      onSignOut: _signOut,
      onTheme: widget.onTheme,
      onReplace: (replacement) {
        replacement.month(monthKey(ledgerToday()));
        replacement.goals;
        _workspace = replacement;
        _schedule();
      },
    );
  }
}
