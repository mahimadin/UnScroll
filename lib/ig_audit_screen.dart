import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Instagram follower audit using the official "Download your information"
/// export (JSON). No login, no password, no network calls to Instagram.
/// Everything stays on-device without requiring problematic third-party file pickers.
class IgAuditScreen extends StatefulWidget {
  const IgAuditScreen({super.key});
  @override
  State<IgAuditScreen> createState() => _IgAuditScreenState();
}

class _IgAuditScreenState extends State<IgAuditScreen> {
  Set<String> followers = {}, following = {}, done = {};
  late SharedPreferences p;
  bool loaded = false;
  String q = '';
  String? msg;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((v) {
      p = v;
      setState(() {
        followers = (p.getStringList('ig_followers') ?? []).toSet();
        following = (p.getStringList('ig_following') ?? []).toSet();
        done = (p.getStringList('ig_done') ?? []).toSet();
        loaded = true;
      });
    });
  }

  /// Extract usernames from either export shape (Map wrapper or bare List).
  Set<String> parse(String raw) {
    final j = jsonDecode(raw);
    final List list = j is List
        ? j
        : (j as Map).values.firstWhere((v) => v is List, orElse: () => []);
    final out = <String>{};
    for (final e in list) {
      if (e is! Map) continue;
      final data = (e['string_list_data'] as List?) ?? [];
      final entry = data.isNotEmpty ? data.first as Map : {};
      var name = (entry['value'] ?? '').toString();
      if (name.isEmpty) name = (e['title'] ?? '').toString();
      if (name.isEmpty) {
        final href = (entry['href'] ?? '').toString();
        name = href.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
      }
      if (name.isNotEmpty) out.add(name.toLowerCase());
    }
    return out;
  }

  Future<void> showImportDialog() async {
    final followersCtrl = TextEditingController();
    final followingCtrl = TextEditingController();
    final pathCtrl = TextEditingController(text: '/storage/emulated/0/Download');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Import Instagram JSON',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Option 1: Auto-scan a folder on your phone',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7C5CFF))),
              const SizedBox(height: 6),
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(
                    labelText: 'Folder path',
                    hintText: '/storage/emulated/0/Download'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () {
                  final dir = Directory(pathCtrl.text.trim());
                  if (!dir.existsSync()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Folder not found or not accessible.')));
                    return;
                  }
                  final fers = <String>{}, fing = <String>{};
                  try {
                    for (final entity in dir.listSync(recursive: true)) {
                      if (entity is File && entity.path.endsWith('.json')) {
                        final name = entity.uri.pathSegments.last.toLowerCase();
                        if (name.startsWith('followers')) {
                          fers.addAll(parse(entity.readAsStringSync()));
                        } else if (name.startsWith('following')) {
                          fing.addAll(parse(entity.readAsStringSync()));
                        }
                      }
                    }
                    if (fers.isEmpty || fing.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not find both followers_*.json and following.json in this folder.')));
                      return;
                    }
                    saveData(fers, fing);
                    Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error reading folder: $e')));
                  }
                },
                child: const Text('Scan Folder for JSON Files'),
              ),
              const Divider(height: 32),
              const Text('Option 2: Paste JSON content directly',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7C5CFF))),
              const SizedBox(height: 8),
              TextField(
                controller: followersCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Paste followers_1.json text here',
                    hintText: '[{"string_list_data": [...]}]'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: followingCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Paste following.json text here',
                    hintText: '{"relationships_following": [...]}'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  try {
                    final fers = parse(followersCtrl.text.trim());
                    final fing = parse(followingCtrl.text.trim());
                    if (fers.isEmpty || fing.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please paste valid JSON for both fields.')));
                      return;
                    }
                    saveData(fers, fing);
                    Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid JSON format: $e')));
                  }
                },
                child: const Text('Process Pasted Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveData(Set<String> fers, Set<String> fing) async {
    await p.setStringList('ig_followers', fers.toList());
    await p.setStringList('ig_following', fing.toList());
    setState(() {
      followers = fers;
      following = fing;
      msg = null;
    });
  }

  Future<void> open(String u) =>
      launchUrl(Uri.parse('https://www.instagram.com/$u/'),
          mode: LaunchMode.externalApplication);

  void toggleDone(String u) {
    setState(() => done.contains(u) ? done.remove(u) : done.add(u));
    p.setStringList('ig_done', done.toList());
  }

  Widget list(List<String> ids, {bool unfollowHint = false}) {
    final f = ids.where((u) => u.contains(q.toLowerCase())).toList()..sort();
    if (f.isEmpty) {
      return const Center(
          child: Text('Nothing here', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: f.length,
      itemBuilder: (_, i) {
        final u = f[i];
        final d = done.contains(u);
        return ListTile(
          leading: unfollowHint
              ? Checkbox(value: d, onChanged: (_) => toggleDone(u))
              : const Icon(Icons.person_outline),
          title: Text(u,
              style: TextStyle(
                  decoration: d ? TextDecoration.lineThrough : null,
                  color: d ? Colors.white38 : null)),
          trailing: TextButton(
              onPressed: () => open(u),
              child: Text(unfollowHint ? 'Open to unfollow' : 'Open')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final hasData = followers.isNotEmpty || following.isNotEmpty;
    final notBack = following.difference(followers).toList();
    final fans = followers.difference(following).toList();
    final mutual = following.intersection(followers).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram audit'),
        actions: [
          IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import export data',
              onPressed: showImportDialog),
          if (hasData)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete imported data',
                onPressed: () async {
                  await p.remove('ig_followers');
                  await p.remove('ig_following');
                  await p.remove('ig_done');
                  setState(() {
                    followers = {};
                    following = {};
                    done = {};
                  });
                }),
        ],
      ),
      body: !hasData
          ? ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Find who doesn\'t follow you back — privately.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                  'No Instagram login needed. Your data never leaves this phone.\n\n'
                  '1. Instagram → Settings → Accounts Center → Your information and permissions → Download your information.\n'
                  '2. Choose "Some of your information" → Followers and following. Date range: All time. Format: JSON. Submit.\n'
                  '3. When the email arrives, download and unzip it. Files are in connections/followers_and_following/.\n'
                  '4. Tap Import below to scan the Download folder or paste the JSON text.',
                  style: TextStyle(height: 1.5, color: Colors.white70)),
              if (msg != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(msg!,
                        style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: showImportDialog,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import data')),
            ])
          : DefaultTabController(
              length: 3,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: TextField(
                      onChanged: (v) => setState(() => q = v),
                      decoration: const InputDecoration(
                          hintText: 'Search', prefixIcon: Icon(Icons.search))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                      '${following.length} following · ${followers.length} followers',
                      style: const TextStyle(color: Colors.white54)),
                ),
                TabBar(tabs: [
                  Tab(text: 'Not back (${notBack.length})'),
                  Tab(text: 'Fans (${fans.length})'),
                  Tab(text: 'Mutual (${mutual.length})'),
                ]),
                Expanded(
                  child: TabBarView(children: [
                    Column(children: [
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                            'Tip: unfollow in small batches (≈30–50/day). Mass-unfollowing can get your account action-blocked. Tick the box to track progress.',
                            style: TextStyle(fontSize: 12, color: Colors.amber)),
                      ),
                      Expanded(child: list(notBack, unfollowHint: true)),
                    ]),
                    list(fans),
                    list(mutual),
                  ]),
                ),
              ]),
            ),
    );
  }
}
