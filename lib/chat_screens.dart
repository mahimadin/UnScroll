import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'store.dart';
import 'profile_screens.dart' show Avatar;

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  String preview(String peer) {
    final t = store.thread(peer);
    if (t.isEmpty) return '';
    final m = t.last;
    final who = m.from == store.me ? 'You: ' : '';
    if (m.mediaType == 'video') return '${who}🎬 Video';
    if (m.mediaType == 'image') return '${who}📷 Photo';
    return '$who${m.text ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final convs = store.conversations;
        return Scaffold(
          appBar: AppBar(
              title: const Text('Messages',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final others =
                  store.users.keys.where((u) => u != store.me).toList();
              final pick = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => ListView(children: [
                  for (final u in others)
                    ListTile(
                        leading: Avatar(id: u, radius: 18),
                        title: Text(u),
                        onTap: () => Navigator.pop(context, u)),
                ]),
              );
              if (pick != null && context.mounted) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen(peerId: pick)));
              }
            },
            child: const Icon(Icons.edit_outlined),
          ),
          body: convs.isEmpty
              ? const Center(
                  child: Text('No conversations yet',
                      style: TextStyle(color: Colors.white54)))
              : ListView(children: [
                  for (final p in convs)
                    ListTile(
                      leading: Avatar(id: p, radius: 24),
                      title: Text(p),
                      subtitle: Text(preview(p),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(ago(store.thread(p).last.time),
                          style: const TextStyle(color: Colors.white38)),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatScreen(peerId: p))),
                    ),
                ]),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String peerId;
  const ChatScreen({super.key, required this.peerId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctl = TextEditingController();

  void sendText() {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    store.send(widget.peerId, text: t);
    ctl.clear();
  }

  Future<void> sendImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1440, imageQuality: 85);
    if (x != null) store.send(widget.peerId, media: x.path, type: 'image');
  }

  Future<void> sendVideo() async {
    final x = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (x != null) store.send(widget.peerId, media: x.path, type: 'video');
  }

  Widget bubble(Msg m) {
    final mine = m.from == store.me;
    Widget content;
    if (m.mediaType == 'image') {
      content = GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                    appBar: AppBar(),
                    backgroundColor: Colors.black,
                    body: Center(
                        child: InteractiveViewer(
                            child: Image.file(File(m.mediaPath!))))))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(m.mediaPath!),
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                  width: 220, height: 120, child: Icon(Icons.broken_image))),
        ),
      );
    } else if (m.mediaType == 'video') {
      content = GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => VideoScreen(path: m.mediaPath!))),
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
              color: Colors.black45, borderRadius: BorderRadius.circular(12)),
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill, size: 48),
                SizedBox(height: 6),
                Text('Video · tap to play',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
        ),
      );
    } else {
      content = Text(m.text ?? '', style: const TextStyle(fontSize: 16));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF5A3FD6) : const Color(0xFF1E1E27),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.storyCaption != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('↩ Replied to story: ${m.storyCaption}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              content,
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Avatar(id: widget.peerId, radius: 16),
          const SizedBox(width: 10),
          Text(widget.peerId),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (_, __) {
              final msgs = store.thread(widget.peerId).reversed.toList();
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) => bubble(msgs[i]),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Row(children: [
              IconButton(
                  onPressed: sendImage, icon: const Icon(Icons.image_outlined)),
              IconButton(
                  onPressed: sendVideo,
                  icon: const Icon(Icons.videocam_outlined)),
              Expanded(
                child: TextField(
                    controller: ctl,
                    onSubmitted: (_) => sendText(),
                    decoration: const InputDecoration(hintText: 'Message…')),
              ),
              IconButton(onPressed: sendText, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Isolated, single-video player. No queue, no autoplay of other content.
class VideoScreen extends StatefulWidget {
  final String path;
  const VideoScreen({super.key, required this.path});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController c;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => ready = true);
        c.play();
      });
    c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: !ready
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                AspectRatio(
                    aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
                VideoProgressIndicator(c, allowScrubbing: true),
                IconButton(
                  iconSize: 40,
                  icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () =>
                      c.value.isPlaying ? c.pause() : c.play(),
                ),
              ]),
      ),
    );
  }
}
