import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'local-emulator-only',
      appId: '1:123456789:android:1234567890abcdef',
      messagingSenderId: '123456789',
      projectId: 'demo-cloud-quest',
    ),
  );
  const host = '10.0.2.2';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  runApp(const CloudQuest());
}

class CloudQuest extends StatelessWidget {
  const CloudQuest({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cloud Quest',
    theme: ThemeData(colorSchemeSeed: const Color(0xff245d68)),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null
            ? const SignIn()
            : Quest(key: ValueKey(user.uid), uid: user.uid);
      },
    ),
  );
}

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String message = '';

  Future<void> authenticate(bool register) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final auth = FirebaseAuth.instance;
      if (register) {
        await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException {
      if (mounted) {
        setState(
          () => message = 'Check your email and password, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud Quest')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Sign in to start',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : () => authenticate(false),
          child: const Text('Sign in'),
        ),
        OutlinedButton(
          onPressed: busy ? null : () => authenticate(true),
          child: const Text('Create account'),
        ),
        if (message.isNotEmpty) Text(message),
      ],
    ),
  );
}

class Quest extends StatefulWidget {
  const Quest({super.key, required this.uid});
  final String uid;

  @override
  State<Quest> createState() => _QuestState();
}

class _QuestState extends State<Quest> {
  final question = TextEditingController();
  late final challenge = FirebaseFirestore.instance
      .doc('challenges/today')
      .snapshots();
  late final progress = FirebaseFirestore.instance
      .doc('users/${widget.uid}/progress/today')
      .snapshots();
  bool busy = false;
  String message = '';

  Future<void> request(bool complete) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final name = complete ? 'completeToday' : 'askQuestCoach';
      final result = await callLocalFunction(
        name,
        complete
            ? {'challengeId': 'today'}
            : {'question': question.text.trim()},
      );
      if (!mounted) return;
      setState(
        () => message = complete
            ? (result['alreadyCompleted'] == true
                  ? 'Already completed. Your reward is unchanged.'
                  : 'You earned 10 points and the First Quest badge.')
            : result['reply'] as String,
      );
    } catch (error) {
      debugPrint('Quest request failed: $error');
      if (mounted) {
        setState(
          () => message = complete
              ? 'Could not complete the quest. Try again.'
              : 'Could not get a hint. Enter a question or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cloud Quest'),
      actions: [
        TextButton(
          onPressed: FirebaseAuth.instance.signOut,
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: challenge,
      builder: (context, quest) {
        if (quest.hasError) {
          return const Center(child: Text('Could not load the challenge.'));
        }
        if (!quest.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = quest.data!.data();
        if (data == null) {
          return const Center(child: Text('No challenge available.'));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: progress,
          builder: (context, saved) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                data['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(data['prompt'] as String),
              const SizedBox(height: 16),
              if (saved.hasError)
                const Text('Could not read your progress.')
              else if (saved.hasData)
                Text('Points: ${saved.data!.data()?['points'] ?? 0}'),
              if (saved.data?.data()?['badgeId'] == 'first-quest')
                const Text('Badge: First Quest'),
              FilledButton(
                onPressed: busy ? null : () => request(true),
                child: const Text('Complete challenge'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: question,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Ask the Quest Coach',
                ),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => request(false),
                child: const Text('Get hint'),
              ),
              if (busy) const LinearProgressIndicator(),
              if (message.isNotEmpty) Text(message),
            ],
          ),
        );
      },
    ),
  );
}

Future<Map<String, dynamic>> callLocalFunction(
  String name,
  Map<String, String> data,
) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Sign in first');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.postUrl(
      Uri.parse('http://10.0.2.2:5001/demo-cloud-quest/us-central1/$name'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode({'data': data}));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw HttpException('Callable returned ${response.statusCode}');
    }
    return (jsonDecode(body) as Map<String, dynamic>)['result']
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}
