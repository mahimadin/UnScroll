import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'store.dart';
import 'profile_screens.dart' show Avatar;

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mine = store.activeStoriesOf(store.me!);
        final authors = store.storyAuthors;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Unscroll',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_a_photo_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StoryComposeScreen())),
              ),
            ],
          ),
          body: ListView(
            children: [
              ListTile(
                leading: Avatar(id: store.me!, radius: 26, ring: mine.isEmpty ? 0 : 1),
                title: const Text('Your story'),
                subtitle: Text(mine.isEmpty
                    ? 'Tap to share a moment'
                    : '${mine.length} active · expires in 24h'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => mine.isEmpty
                            ? const StoryComposeScreen()
                            : StoryViewer(authorId: store.me!))),
              ),
              const Divider(height: 1),
              if (authors.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                      child: Text("You're all caught up.\nNothing to scroll. 🌿",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
                ),
              for (final a in authors)
                ListTile(
                  leading: Avatar(id: a, radius: 26, ring: store.allSeen(a) ? 2 : 1),
                  title: Text(a),
                  subtitle: Text(ago(store.activeStoriesOf(a).last.createdAt)),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => StoryViewer(authorId: a))),
                ),
            ],
          ),
        );
      },
    );
  }
}

class StoryComposeScreen extends StatefulWidget {
  const StoryComposeScreen({super.key});
  @override
  State<StoryComposeScreen> createState() => _StoryComposeScreenState();
}

class _StoryComposeScreenState extends State<StoryComposeScreen> {
  String? path;
  final caption = TextEditingController();

  Future<void> pick(ImageSource s) async {
    final x = await ImagePicker().pickImage(
        source: s, maxWidth: 1440, imageQuality: 85);
    if (x != null) setState(() => path = x.path);
  }

  @override
  Widget build(BuildContext context) {
    final c = Color(store.users[store.me]!.color);
    return Scaffold(
      appBar: AppBar(title: const Text('New story')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: path == null
                    ? BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [c, Colors.black]))
                    : null,
                child: path == null
                    ? const Center(
                        child: Text('Add a photo or just write a caption',
                            style: TextStyle(color: Colors.white70)))
                    : Image.file(File(path!), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'))),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: caption,
              maxLength: 120,
              decoration: const InputDecoration(hintText: 'Caption')),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                if (path == null && caption.text.trim().isEmpty) return;
                store.addStory(caption.text, path);
                Navigator.pop(context);
              },
              child: const Text('Share story'),
            ),
          ),
        ]),
      ),
    );
  }
}

class StoryViewer extends StatefulWidget {
  final String authorId;
  const StoryViewer({super.key, required this.authorId});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late List<Story> items;
  int i = 0;
  Timer? timer;
  final ctl = TextEditingController();
  final focus = FocusNode();

  bool get own => widget.authorId == store.me;

  @override
  void initState() {
    super.initState();
    items = store.activeStoriesOf(widget.authorId);
    focus.addListener(() => focus.hasFocus ? timer?.cancel() : start());
    if (items.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => Navigator.maybePop(context));
    } else {
      start();
    }
  }

  void start() {
    timer?.cancel();
    if (items.isEmpty) return;
    store.markViewed(items[i]);
    timer = Timer(const Duration(seconds: 5), next);
  }

  void next() {
    if (i < items.length - 1) {
      setState(() => i++);
      start();
    } else {
      Navigator.maybePop(context);
    }
  }

  void prev() {
    if (i > 0) {
      setState(() => i--);
      start();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    ctl.dispose();
    focus.dispose();
    super.dispose();
  }

  void showViewers() {
    timer?.cancel();
    final s = items[i];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Seen by ${s.viewers.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (s.viewers.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24), child: Text('No views yet')),
          for (final v in s.viewers)
            ListTile(leading: Avatar(id: v, radius: 18), title: Text(v)),
        ]),
      ),
    ).whenComplete(start);
  }

  void reply() {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    store.send(widget.authorId, text: t, story: items[i]);
    ctl.clear();
    focus.unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reply sent to their DMs')));
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Scaffold();
    final s = items[i];
    final c = Color(s.color);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(children: [
              for (var k = 0; k < items.length; k++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                        color: k <= i ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
            ]),
          ),
          ListTile(
            dense: true,
            leading: Avatar(id: widget.authorId, radius: 16),
            title: Text(widget.authorId),
            subtitle: Text(ago(s.createdAt)),
            trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    d.localPosition.dx < box.maxWidth / 3 ? prev() : next(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(fit: StackFit.expand, children: [
                    if (s.imagePath != null)
                      Image.file(File(s.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)))
                    else
                      Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [c, c.withOpacity(.4), Colors.black])),
                      ),
                    if (s.caption.isNotEmpty)
                      Align(
                        alignment: s.imagePath == null
                            ? Alignment.center
                            : Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(s.caption,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: own
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: showViewers,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text('Seen by ${s.viewers.length}'),
                    ))
                : Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctl,
                        focusNode: focus,
                        onSubmitted: (_) => reply(),
                        decoration:
                            InputDecoration(hintText: 'Reply to ${widget.authorId}…'),
                      ),
                    ),
                    IconButton(onPressed: reply, icon: const Icon(Icons.send)),
                  ]),
          ),
        ]),
      ),
    );
  }
}
