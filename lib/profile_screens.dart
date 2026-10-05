import 'package:flutter/material.dart';
import 'ig_audit_screen.dart';
import 'store.dart';
import 'chat_screens.dart';

class Avatar extends StatelessWidget {
  final String id;
  final double radius;

  /// 0 = no ring, 1 = unseen story ring, 2 = seen story ring
  final int ring;
  const Avatar({super.key, required this.id, this.radius = 20, this.ring = 0});

  @override
  Widget build(BuildContext context) {
    final u = store.users[id];
    final av = CircleAvatar(
      radius: radius,
      backgroundColor: Color(u?.color ?? 0xFF555555),
      child: Text(id.isEmpty ? '?' : id[0].toUpperCase(),
          style: TextStyle(
              fontSize: radius * .8,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
    if (ring == 0) return av;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring == 1
            ? const LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFFFF5C8A)])
            : const LinearGradient(colors: [Colors.white24, Colors.white24]),
      ),
      child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF0B0B0F)),
          child: av),
    );
  }
}

class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});
  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  String q = '';

  Widget action(String id) {
    if (store.isFollowing(id)) {
      return OutlinedButton(
          onPressed: () => store.unfollow(id), child: const Text('Following'));
    }
    if (store.hasRequested(id)) {
      return OutlinedButton(
          onPressed: () => store.cancelRequest(id),
          child: const Text('Requested'));
    }
    return FilledButton(
        onPressed: () => store.follow(id),
        child: Text(store.followsMe(id) ? 'Follow back' : 'Follow'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ids = store.users.keys
            .where((u) => u != store.me && u.contains(q.toLowerCase()))
            .toList();
        return Scaffold(
          appBar: AppBar(
              title: const Text('People',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                    hintText: 'Search by username',
                    prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: ListView(children: [
                for (final id in ids)
                  ListTile(
                    leading: Avatar(id: id, radius: 22),
                    title: Row(children: [
                      Text(id),
                      if (store.users[id]!.isPrivate)
                        const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock, size: 14, color: Colors.white54)),
                    ]),
                    subtitle: Text(store.users[id]!.bio,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(peerId: id)))),
                      action(id),
                    ]),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Widget stat(String label, int n) => Column(children: [
        Text('$n',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.users[store.me]!;
        final pending = store.incomingRequests.length;
        final nfb = store.notFollowingBack.length;
        return Scaffold(
          appBar: AppBar(
            title: Text(me.id,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Log out',
                  onPressed: store.logout),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Avatar(id: me.id, radius: 38),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      stat('Following', store.following[me.id]?.length ?? 0),
                      stat('Followers', store.followers.length),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(me.bio),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit bio'),
                onPressed: () async {
                  final c = TextEditingController(text: me.bio);
                  final r = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Edit bio'),
                      content: TextField(controller: c, maxLength: 100),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, c.text),
                            child: const Text('Save')),
                      ],
                    ),
                  );
                  if (r != null) store.setBio(r);
                },
              ),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Private account'),
              subtitle: const Text('People must request to follow you'),
              value: me.isPrivate,
              onChanged: store.setPrivate,
            ),
            ListTile(
              leading: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  child: const Icon(Icons.person_add_alt_1_outlined)),
              title: const Text('Follow requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RequestsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Not following back'),
              subtitle: Text('$nfb account${nfb == 1 ? '' : 's'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotFollowingBackScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Instagram audit'),
              subtitle: const Text('Import your Instagram export — no login'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const IgAuditScreen())),
            ),
          ]),
        );
      },
    );
  }
}

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final reqs = store.incomingRequests;
        return Scaffold(
          appBar: AppBar(title: const Text('Follow requests')),
          body: reqs.isEmpty
              ? const Center(
                  child: Text('No pending requests',
                      style: TextStyle(color: Colors.white54)))
              : ListView(children: [
                  for (final r in reqs)
                    ListTile(
                      leading: Avatar(id: r, radius: 22),
                      title: Text(r),
                      subtitle: const Text('wants to follow you'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        FilledButton(
                            onPressed: () => store.acceptRequest(r),
                            child: const Text('Accept')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                            onPressed: () => store.deleteRequest(r),
                            child: const Text('Delete')),
                      ]),
                    ),
                ]),
        );
      },
    );
  }
}

class NotFollowingBackScreen extends StatelessWidget {
  const NotFollowingBackScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ids = store.notFollowingBack;
        return Scaffold(
          appBar: AppBar(title: const Text('Not following back')),
          body: ids.isEmpty
              ? const Center(
                  child: Text('Everyone you follow follows you back 🎉',
                      style: TextStyle(color: Colors.white54)))
              : ListView(children: [
                  for (final id in ids)
                    ListTile(
                      leading: Avatar(id: id, radius: 22),
                      title: Text(id),
                      subtitle: Text(store.users[id]?.bio ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: FilledButton.tonal(
                          onPressed: () => store.unfollow(id),
                          child: const Text('Unfollow')),
                    ),
                ]),
        );
      },
    );
  }
}
