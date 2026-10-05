import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local data layer. Everything is persisted in SharedPreferences as JSON.
/// Seeded "bot" accounts simulate other people (follow-backs, replies, views).
const bots = ['alice', 'bob', 'carol', 'dave', 'erin'];
const _palette = [
  0xFF7C5CFF, 0xFFFF5C8A, 0xFF22C3A6, 0xFFFFA63D, 0xFF3D8BFF, 0xFFB65CFF,
];
const _botBio = {
  'alice': 'Coffee, trails & film cameras.',
  'bob': 'Building things slowly.',
  'carol': 'Books > feeds.',
  'dave': 'Offline most of the day.',
  'erin': 'Private account. Request to follow.',
};
const _botStories = {
  'alice': ['Sunrise hike 🌄', 'Fresh brew ☕'],
  'bob': ['Shipping day 🚀'],
  'carol': ['Currently reading 📖'],
  'dave': ['No signal, no problem 🌲'],
  'erin': ['Only followers see this 🔒'],
};
const _replies = [
  'Haha nice!', 'Love that 🙌', 'Tell me more', 'Ok sounds good', 'Same here!',
  'Talk later?',
];

int _now() => DateTime.now().millisecondsSinceEpoch;
const _day = 24 * 60 * 60 * 1000;

class AppUser {
  final String id;
  String bio;
  bool isPrivate;
  final int color;
  AppUser(this.id, {this.bio = '', this.isPrivate = false, required this.color});
  Map<String, dynamic> toJson() =>
      {'id': id, 'bio': bio, 'p': isPrivate, 'c': color};
  factory AppUser.fromJson(Map j) => AppUser(j['id'],
      bio: j['bio'] ?? '', isPrivate: j['p'] ?? false, color: j['c']);
}

class Story {
  final String id, authorId, caption;
  final String? imagePath;
  final int color, createdAt;
  final List<String> viewers;
  Story(this.id, this.authorId, this.caption, this.imagePath, this.color,
      this.createdAt, this.viewers);
  bool get active => _now() - createdAt < _day;
  Map<String, dynamic> toJson() => {
        'id': id, 'a': authorId, 'cap': caption, 'img': imagePath,
        'c': color, 't': createdAt, 'v': viewers,
      };
  factory Story.fromJson(Map j) => Story(j['id'], j['a'], j['cap'], j['img'],
      j['c'], j['t'], List<String>.from(j['v']));
}

class Msg {
  final String id, from, to;
  final String? text, mediaPath, mediaType, storyCaption;
  final int time;
  Msg(this.id, this.from, this.to, this.time,
      {this.text, this.mediaPath, this.mediaType, this.storyCaption});
  Map<String, dynamic> toJson() => {
        'id': id, 'f': from, 'to': to, 't': time, 'txt': text,
        'mp': mediaPath, 'mt': mediaType, 'sc': storyCaption,
      };
  factory Msg.fromJson(Map j) => Msg(j['id'], j['f'], j['to'], j['t'],
      text: j['txt'], mediaPath: j['mp'], mediaType: j['mt'], storyCaption: j['sc']);
}

class Store extends ChangeNotifier {
  late SharedPreferences _p;
  Map<String, AppUser> users = {};
  Map<String, Set<String>> following = {};
  List<List<String>> requests = []; // [fromId, toId]
  List<Story> stories = [];
  List<Msg> messages = [];
  Map<String, String> creds = {};
  String? me;
  int _seq = 0;

  String _id(String p) => '$p${_now()}_${_seq++}';

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('db');
    if (raw != null) {
      final j = jsonDecode(raw);
      users = {
        for (final u in j['users']) u['id'] as String: AppUser.fromJson(u)
      };
      following = {
        for (final e in (j['following'] as Map).entries)
          e.key as String: Set<String>.from(e.value)
      };
      requests = [for (final r in j['requests']) List<String>.from(r)];
      stories = [for (final s in j['stories']) Story.fromJson(s)];
      messages = [for (final m in j['messages']) Msg.fromJson(m)];
      creds = Map<String, String>.from(j['creds']);
    } else {
      _seed();
    }
    me = _p.getString('me');
    if (me != null && !users.containsKey(me)) me = null;
    _refreshBots();
    _save();
  }

  void _seed() {
    for (var i = 0; i < bots.length; i++) {
      users[bots[i]] = AppUser(bots[i],
          bio: _botBio[bots[i]]!,
          isPrivate: bots[i] == 'erin',
          color: _palette[i % _palette.length]);
    }
    following = {
      'alice': {'bob', 'carol'},
      'bob': {'alice'},
      'carol': {'alice', 'dave'},
      'dave': <String>{},
      'erin': {'alice'},
    };
  }

  /// Bots re-post a story if theirs expired (keeps demo alive across days).
  void _refreshBots() {
    stories.removeWhere((s) => !s.active && bots.contains(s.authorId));
    for (final b in bots) {
      if (!stories.any((s) => s.authorId == b && s.active)) {
        final caps = _botStories[b]!;
        for (var i = 0; i < caps.length; i++) {
          stories.add(Story(_id('s'), b, caps[i], null,
              users[b]!.color + i * 40, _now() - (i + 1) * 3600000, []));
        }
      }
    }
  }

  void _save() {
    _p.setString(
        'db',
        jsonEncode({
          'users': users.values.map((e) => e.toJson()).toList(),
          'following': following.map((k, v) => MapEntry(k, v.toList())),
          'requests': requests,
          'stories': stories.map((e) => e.toJson()).toList(),
          'messages': messages.map((e) => e.toJson()).toList(),
          'creds': creds,
        }));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  // ---------- Auth ----------
  String? signup(String name, String pw) {
    final id = name.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(id)) {
      return 'Username: 3-20 letters, numbers, _ or .';
    }
    if (pw.length < 4) return 'Password must be at least 4 characters';
    if (users.containsKey(id)) return 'That username is taken';
    creds[id] = pw;
    users[id] = AppUser(id,
        bio: 'New here ✨', color: _palette[users.length % _palette.length]);
    following[id] = {'alice', 'bob', 'carol', 'dave'};
    following['alice']!.add(id);
    following['carol']!.add(id);
    requests.add(['erin', id]);
    messages.add(Msg(_id('m'), 'alice', id, _now(),
        text: 'Welcome to Unscroll! No feeds here, just people.'));
    me = id;
    _p.setString('me', id);
    _refreshBots();
    _commit();
    return null;
  }

  String? login(String name, String pw) {
    final id = name.trim().toLowerCase();
    if (creds[id] == null || creds[id] != pw) return 'Wrong username or password';
    me = id;
    _p.setString('me', id);
    _refreshBots();
    _commit();
    return null;
  }

  void logout() {
    me = null;
    _p.remove('me');
    notifyListeners();
  }

  // ---------- Follow graph ----------
  bool isFollowing(String id) => following[me]?.contains(id) ?? false;
  bool followsMe(String id) => following[id]?.contains(me) ?? false;
  bool hasRequested(String id) =>
      requests.any((r) => r[0] == me && r[1] == id);
  List<String> get followers =>
      following.entries.where((e) => e.value.contains(me)).map((e) => e.key).toList();

  void follow(String id) {
    if (isFollowing(id) || hasRequested(id)) return;
    final mine = me!;
    if (users[id]!.isPrivate) {
      requests.add([mine, id]);
      if (bots.contains(id)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (requests.any((r) => r[0] == mine && r[1] == id)) {
            requests.removeWhere((r) => r[0] == mine && r[1] == id);
            following.putIfAbsent(mine, () => {}).add(id);
            _commit();
          }
        });
      }
    } else {
      following.putIfAbsent(mine, () => {}).add(id);
      // Deterministic simulated follow-back for some bots.
      if (bots.contains(id) && id.codeUnits.fold<int>(0, (a, b) => a + b) % 2 == 0) {
        Future.delayed(const Duration(seconds: 1), () {
          following.putIfAbsent(id, () => {}).add(mine);
          _commit();
        });
      }
    }
    _commit();
  }

  void unfollow(String id) {
    following[me]?.remove(id);
    _commit();
  }

  void cancelRequest(String id) {
    requests.removeWhere((r) => r[0] == me && r[1] == id);
    _commit();
  }

  List<String> get incomingRequests =>
      requests.where((r) => r[1] == me).map((r) => r[0]).toList();

  void acceptRequest(String from) {
    requests.removeWhere((r) => r[0] == from && r[1] == me);
    following.putIfAbsent(from, () => {}).add(me!);
    _commit();
  }

  void deleteRequest(String from) {
    requests.removeWhere((r) => r[0] == from && r[1] == me);
    _commit();
  }

  void setPrivate(bool v) {
    users[me]!.isPrivate = v;
    _commit();
  }

  void setBio(String b) {
    users[me]!.bio = b;
    _commit();
  }

  /// Accounts I follow who don't follow me back.
  List<String> get notFollowingBack =>
      (following[me] ?? {}).where((id) => !followsMe(id)).toList();

  // ---------- Stories ----------
  List<Story> activeStoriesOf(String id) {
    final l = stories.where((s) => s.authorId == id && s.active).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return l;
  }

  /// Authors I follow with active stories, newest first.
  List<String> get storyAuthors {
    final ids = (following[me] ?? {})
        .where((id) => activeStoriesOf(id).isNotEmpty)
        .toList();
    int latest(String id) => activeStoriesOf(id).last.createdAt;
    ids.sort((a, b) => latest(b).compareTo(latest(a)));
    return ids;
  }

  bool allSeen(String authorId) =>
      activeStoriesOf(authorId).every((s) => s.viewers.contains(me));

  void addStory(String caption, String? imagePath) {
    final mine = me!;
    stories.add(Story(_id('s'), mine, caption.trim(), imagePath,
        users[mine]!.color, _now(), []));
    _commit();
    // Simulate bot followers viewing the story.
    Future.delayed(const Duration(seconds: 3), () {
      final s = stories.last;
      for (final b in bots) {
        if (followsMe(b) == false && !(following[b]?.contains(mine) ?? false)) continue;
        if (!s.viewers.contains(b)) s.viewers.add(b);
      }
      _commit();
    });
  }

  void markViewed(Story s) {
    if (s.authorId != me && !s.viewers.contains(me)) {
      s.viewers.add(me!);
      _save();
    }
  }

  // ---------- Messaging ----------
  List<Msg> thread(String peer) => messages
      .where((m) =>
          (m.from == me && m.to == peer) || (m.from == peer && m.to == me))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  List<String> get conversations {
    final last = <String, int>{};
    for (final m in messages) {
      if (m.from == me) last[m.to] = m.time;
      if (m.to == me) last[m.from] = m.time;
    }
    final ids = last.keys.toList()
      ..sort((a, b) => last[b]!.compareTo(last[a]!));
    return ids;
  }

  void send(String to,
      {String? text, String? media, String? type, Story? story}) {
    final mine = me!;
    messages.add(Msg(_id('m'), mine, to, _now(),
        text: text,
        mediaPath: media,
        mediaType: type,
        storyCaption: story == null
            ? null
            : (story.caption.isEmpty ? 'a story' : story.caption)));
    _commit();
    if (bots.contains(to)) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        messages.add(Msg(_id('m'), to, mine, _now(),
            text: _replies[_seq % _replies.length]));
        _commit();
      });
    }
  }
}

final store = Store();

String ago(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
