import 'package:flutter/material.dart';
import 'store.dart';
import 'home_screens.dart';
import 'chat_screens.dart';
import 'profile_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const UnscrollApp());
}

class UnscrollApp extends StatelessWidget {
  const UnscrollApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unscroll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C5CFF), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0B0F), elevation: 0, centerTitle: false),
        navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF111116)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A22),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
        ),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (_, __) =>
            store.me == null ? const AuthScreen() : const HomeShell(),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool signup = true;
  String? error;

  void submit() {
    final e = signup
        ? store.signup(user.text, pass.text)
        : store.login(user.text, pass.text);
    if (e != null) setState(() => error = e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.self_improvement, size: 64, color: Color(0xFF7C5CFF)),
                const SizedBox(height: 8),
                const Text('Unscroll',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('People, not feeds.',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 32),
                TextField(
                    controller: user,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'Username')),
                const SizedBox(height: 12),
                TextField(
                    controller: pass,
                    obscureText: true,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(hintText: 'Password')),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                      onPressed: submit,
                      child: Text(signup ? 'Create account' : 'Log in')),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    signup = !signup;
                    error = null;
                  }),
                  child: Text(signup
                      ? 'Have an account? Log in'
                      : 'New here? Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final pending = store.incomingRequests.length;
        return Scaffold(
          body: IndexedStack(index: index, children: const [
            HomeTab(),
            MessagesTab(),
            PeopleTab(),
            ProfileTab(),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: 'Stories'),
              const NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Messages'),
              const NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'People'),
              NavigationDestination(
                  icon: Badge(
                      isLabelVisible: pending > 0,
                      label: Text('$pending'),
                      child: const Icon(Icons.person_outline)),
                  selectedIcon: const Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}
