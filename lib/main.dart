import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(const TypeShiApp());
}

class Song {
  Song({required this.id, required this.title, required this.artist, required this.path});
  final String id;
  final String title;
  final String artist;
  final String path;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'artist': artist, 'path': path};
  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Unknown',
        artist: j['artist'] ?? 'Unknown Artist',
        path: j['path'] ?? '',
      );
}

class Playlist {
  Playlist({required this.id, required this.name, required this.songIds});
  final String id;
  String name;
  final List<String> songIds;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] ?? '',
        name: j['name'] ?? 'Playlist',
        songIds: List<String>.from(j['songIds'] ?? const []),
      );
}

class LyricLine {
  const LyricLine(this.at, this.text);
  final Duration at;
  final String text;
}

class TypeShiApp extends StatelessWidget {
  const TypeShiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TYPE SHI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Color(0xFF0E0E12),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final List<Song> _songs = [];
  final List<Playlist> _playlists = [];
  List<Song> _queue = [];
  int _index = -1;
  int _tab = 0;
  String _query = '';
  String? _bgPath;
  bool _playing = false;
  bool _shuffle = false;
  LoopMode _loop = LoopMode.off;
  double _speed = 1.0;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  Timer? _sleepTimer;
  int? _sleepMinutes;

  Song? get _current => (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;

  @override
  void initState() {
    super.initState();
    _initStorageAndStreams();
  }

  Future<void> _initStorageAndStreams() async {
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _dur = d);
    });
    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      if (st.processingState == ProcessingState.completed && _loop != LoopMode.one) {
        _next();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final rawSongs = prefs.getString('songs');
    if (rawSongs != null && rawSongs.isNotEmpty) {
      final list = jsonDecode(rawSongs) as List;
      _songs.addAll(list.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).where((s) => File(s.path).existsSync()));
    }
    final rawPl = prefs.getString('playlists');
    if (rawPl != null && rawPl.isNotEmpty) {
      final list = jsonDecode(rawPl) as List;
      _playlists.addAll(list.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))));
    }
    final bg = prefs.getString('bgPath');
    if (bg != null && File(bg).existsSync()) {
      _bgPath = bg;
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songs', jsonEncode(_songs.map((e) => e.toJson()).toList()));
    await prefs.setString('playlists', jsonEncode(_playlists.map((e) => e.toJson()).toList()));
    if (_bgPath != null) {
      await prefs.setString('bgPath', _bgPath!);
    } else {
      await prefs.remove('bgPath');
    }
  }

  Future<void> _importSongs() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files == null || files.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    int added = 0;
    for (final f in files) {
      if (f.path == null) continue;
      final ext = f.name.contains('.') ? f.name.substring(f.name.lastIndexOf('.')) : '.mp3';
      final dest = '${dir.path}/track_${DateTime.now().microsecondsSinceEpoch}$ext';
      await File(f.path!).copy(dest);
      final clean = f.name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
      final parts = clean.split(' - ');
      _songs.add(Song(
        id: 's_${DateTime.now().microsecondsSinceEpoch}',
        title: parts.length > 1 ? parts.sublist(1).join(' - ').trim() : clean,
        artist: parts.length > 1 ? parts.first.trim() : 'Unknown Artist',
        path: dest,
      ));
      added++;
    }
    await _saveData();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $added track(s)')));
  }

  Future<void> _pickWallpaper() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final src = (files != null && files.isNotEmpty) ? files.first.path : null;
    if (src == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(src).copy(dest);
    _bgPath = dest;
    await _saveData();
    if (mounted) setState(() {});
  }

  Future<void> _playFromQueue(List<Song> queue, int startIndex) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) return;
    setState(() {
      _queue = List<Song>.from(queue);
      _index = startIndex;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
    await _player.setFilePath(_queue[_index].path);
    await _player.setSpeed(_speed);
    await _player.play();
  }

  Future<void> _next() async {
    if (_queue.isEmpty) return;
    if (_shuffle && _queue.length > 1) {
      final candidates = List.generate(_queue.length, (i) => i)..remove(_index);
      candidates.shuffle();
      await _playFromQueue(_queue, candidates.first);
      return;
    }
    final nextIdx = _index + 1;
    if (nextIdx < _queue.length) {
      await _playFromQueue(_queue, nextIdx);
    } else if (_loop == LoopMode.all) {
      await _playFromQueue(_queue, 0);
    }
  }

  Future<void> _prev() async {
    if (_queue.isEmpty) return;
    if (_pos.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prevIdx = _index - 1;
    if (prevIdx >= 0) {
      await _playFromQueue(_queue, prevIdx);
    } else if (_loop == LoopMode.all) {
      await _playFromQueue(_queue, _queue.length - 1);
    }
  }

  Future<String?> _promptText(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Enter name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  void _openNowPlaying() {
    if (_current == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NowPlayingSheet(
        getSong: () => _current,
        getPlaying: () => _playing,
        getPos: () => _pos,
        getDur: () => _dur,
        getShuffle: () => _shuffle,
        getLoop: () => _loop,
        getSpeed: () => _speed,
        getSleepMinutes: () => _sleepMinutes,
        player: _player,
        onTogglePlay: () => _playing ? _player.pause() : _player.play(),
        onNext: _next,
        onPrev: _prev,
        onToggleShuffle: () => setState(() => _shuffle = !_shuffle),
        onCycleLoop: () async {
          final next = _loop == LoopMode.off ? LoopMode.all : (_loop == LoopMode.all ? LoopMode.one : LoopMode.off);
          await _player.setLoopMode(next);
          setState(() => _loop = next);
        },
        onSetSpeed: (s) async {
          await _player.setSpeed(s);
          setState(() => _speed = s);
        },
        onSetSleep: (mins) {
          _sleepTimer?.cancel();
          setState(() => _sleepMinutes = mins);
          if (mins != null) {
            _sleepTimer = Timer(Duration(minutes: mins), () {
              _player.pause();
              if (mounted) setState(() => _sleepMinutes = null);
            });
          }
        },
      ),
    ));
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _songs.where((s) {
      if (_query.isEmpty) return true;
      return s.title.toLowerCase().contains(_query) || s.artist.toLowerCase().contains(_query);
    }).toList();
return Stack(
children: [
Positioned.fill(child: Container(color: Colors.black)),
if (_bgPath != null)
Positioned.fill(
child: Opacity(opacity: 0.25, child: Image.file(File(_bgPath!), fit: BoxFit.cover)),
),
Scaffold(
backgroundColor: Colors.transparent,
appBar: AppBar(
backgroundColor: Colors.transparent,
title: const Text('TYPE SHI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
actions: [
FilledButton.icon(
onPressed: _importSongs,
icon: const Icon(Icons.add_rounded, size: 18),
label: const Text('Add MP3s'),
),
const SizedBox(width: 12),
],
),
body: _tab == 0
? Column(
children: [
Padding(
padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
child: TextField(
onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
decoration: InputDecoration(
hintText: 'Search songs or artists...',
prefixIcon: const Icon(Icons.search_rounded),
filled: true,
fillColor: const Color(0xFF141418),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
),
),
),
Expanded(
child: filtered.isEmpty
? const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.library_music_rounded, size: 54, color: Colors.white38),
SizedBox(height: 12),
Text('No tracks yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
SizedBox(height: 6),
Text('Tap + Add MP3s to import music from your phone', style: TextStyle(color: Colors.white60)),
],
),
)
: ListView.builder(
padding: const EdgeInsets.only(bottom: 100),
itemCount: filtered.length,
itemBuilder: (ctx, i) {
final s = filtered[i];
final active = _current?.id == s.id;
return ListTile(
leading: Container(
width: 46,
height: 46,
decoration: BoxDecoration(color: const Color(0xFF18181E), borderRadius: BorderRadius.circular(10)),
child: Icon(active ? Icons.equalizer_rounded : Icons.music_note_rounded, color: active ? Colors.white : Colors.white70),
),
title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.white70)),
subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
trailing: PopupMenuButton<String>(
onSelected: (v) async {
if (v == 'pl') {
final name = await _promptText('Playlist name');
if (name != null && name.isNotEmpty) {
final existing = _playlists.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
if (existing.isNotEmpty) {
if (!existing.first.songIds.contains(s.id)) existing.first.songIds.add(s.id);
} else {
_playlists.add(Playlist(id: 'pl${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: [s.id]));
}
await _saveData();
setState(() {});
}
} else if (v == 'ed') {
final newTitle = await _promptText('Rename track', initial: s.title);
if (newTitle != null && newTitle.isNotEmpty) {
final idx = _songs.indexWhere((e) => e.id == s.id);
if (idx >= 0) _songs[idx] = Song(id: s.id, title: newTitle, artist: s.artist, path: s.path);
await _saveData();
setState(() {});
}
} else if (v == 'rm') {
_songs.removeWhere((e) => e.id == s.id);
if (File(s.path).existsSync()) await File(s.path).delete();
await _saveData();
setState(() {});
}
},
itemBuilder: (ctx) => const [
PopupMenuItem(value: 'pl', child: Text('Add to playlist')),
PopupMenuItem(value: 'ed', child: Text('Rename')),
PopupMenuItem(value: 'rm', child: Text('Delete')),
],
),
onTap: () => _playFromQueue(filtered, i),
);
},
),
),
],
)
: _tab == 1
? Column(
children: [
Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
const Expanded(child: Text('Playlists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
FilledButton.icon(
onPressed: () async {
final name = await _promptText('New playlist');
if (name != null && name.isNotEmpty) {
_playlists.add(Playlist(id: 'pl${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: []));
await _saveData();
setState(() {});
}
},
icon: const Icon(Icons.add_rounded),
label: const Text('New'),
),
],
),
),
Expanded(
child: ListView.builder(
itemCount: _playlists.length,
itemBuilder: (ctx, i) {
final pl = _playlists[i];
final plSongs = pl.songIds.map((id) => _songs.where((s) => s.id == id).firstOrNull).whereType<Song>().toList();
return ListTile(
leading: const CircleAvatar(backgroundColor: Color(0xFF1A1A22), child: Icon(Icons.queue_music_rounded, color: Colors.white)),
title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w700)),
subtitle: Text('${plSongs.length} songs'),
trailing: IconButton(
icon: const Icon(Icons.delete_outline_rounded),
onPressed: () async {
_playlists.removeAt(i);
await _saveData();
setState(() {});
},
),
onTap: plSongs.isEmpty ? null : () => _playFromQueue(plSongs, 0),
);
},
),
),
],
)
: ListView(
padding: const EdgeInsets.all(20),
children: [
const Text('Customize TYPE SHI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
const SizedBox(height: 16),
ListTile(
tileColor: const Color(0xFF141418),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
leading: const Icon(Icons.wallpaper_rounded),
title: const Text('Set Custom Background Wallpaper'),
onTap: _pickWallpaper,
),
const SizedBox(height: 12),
if (_bgPath != null)
ListTile(
tileColor: const Color(0xFF141418),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
leading: const Icon(Icons.hide_image_rounded),
title: const Text('Remove Background Wallpaper'),
onTap: () async {
_bgPath = null;
await _saveData();
setState(() {});
},
),
],
),
bottomNavigationBar: Column(
mainAxisSize: MainAxisSize.min,
children: [
if (_current != null)
GestureDetector(
onTap: _openNowPlaying,
child: Container(
margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
decoration: BoxDecoration(color: const Color(0xFF18181F), borderRadius: BorderRadius.circular(16)),
child: Row(
children: [
const Icon(Icons.album_rounded, color: Colors.white),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(_current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
Text(_current!.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white60)),
],
),
),
IconButton(
icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
onPressed: () => _playing ? _player.pause() : _player.play(),
),
IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: _next),
],
),
),
),
NavigationBar(
backgroundColor: const Color(0xFF0A0A0D),
selectedIndex: _tab,
onDestinationSelected: (i) => setState(() => _tab = i),
destinations: const [
NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Library'),
NavigationDestination(icon: Icon(Icons.queue_music_rounded), label: 'Playlists'),
NavigationDestination(icon: Icon(Icons.palette_rounded), label: 'Customize'),
],
),
],
),
),
],
);
}
}
class NowPlayingSheet extends StatefulWidget {
const NowPlayingSheet({
super.key,
required this.getSong,
required this.getPlaying,
required this.getPos,
required this.getDur,
required this.getShuffle,
required this.getLoop,
required this.getSpeed,
required this.getSleepMinutes,
required this.player,
required this.onTogglePlay,
required this.onNext,
required this.onPrev,
required this.onToggleShuffle,
required this.onCycleLoop,
required this.onSetSpeed,
required this.onSetSleep,
});
final Song? Function() getSong;
final bool Function() getPlaying;
final Duration Function() getPos;
final Duration Function() getDur;
final bool Function() getShuffle;
final LoopMode Function() getLoop;
final double Function() getSpeed;
final int? Function() getSleepMinutes;
final AudioPlayer player;
final VoidCallback onTogglePlay;
final VoidCallback onNext;
final VoidCallback onPrev;
final VoidCallback onToggleShuffle;
final Future<void> Function() onCycleLoop;
final Future<void> Function(double) onSetSpeed;
final void Function(int?) onSetSleep;
@override
State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}
class _NowPlayingSheetState extends State<NowPlayingSheet> {
List<LyricLine> _lyrics = [];
bool _loadingLyrics = false;
String? _loadedSongId;
Timer? _uiTick;
@override
void initState() {
super.initState();
_uiTick = Timer.periodic(const Duration(milliseconds: 250), (timer) {
if (!mounted) return;
final cur = widget.getSong();
if (cur != null && cur.id != _loadedSongId) {
_fetchLyrics(cur);
}
setState(() {});
});
final cur = widget.getSong();
if (cur != null) _fetchLyrics(cur);
}
Future _fetchLyrics(Song song) async {
_loadedSongId = song.id;
setState(() {
_loadingLyrics = true;
_lyrics = [];
});
try {
final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)|\(.*?\)'), '').trim();
final cleanArtist = song.artist == 'Unknown Artist' ? '' : song.artist.trim();
final q = Uri.encodeComponent('$cleanTitle $cleanArtist'.trim());
final uri = Uri.parse('lrclib.net');
final res = await http.get(uri, headers: {'User-Agent': 'TypeShiApp/1.0'}).timeout(const Duration(seconds: 6));
if (res.statusCode == 200) {
final list = jsonDecode(res.body) as List;
if (list.isNotEmpty) {
final best = list.firstWhere((e) => (e['syncedLyrics'] ?? '').toString().isNotEmpty, orElse: () => list.first);
final synced = (best['syncedLyrics'] ?? '').toString();
final parsed = <LyricLine>[];
final rx = RegExp(r'(\d+):(\d+)\.(\d+)\s*(.*)');
for (final line in synced.split('\n')) {
final m = rx.firstMatch(line);
if (m != null) {
final min = int.parse(m.group(1)!);
final sec = int.parse(m.group(2)!);
final ms = int.parse(m.group(3)!.padRight(3, '0').substring(0, 3));
final txt = m.group(4)!.trim();
if (txt.isNotEmpty) parsed.add(LyricLine(Duration(minutes: min, seconds: sec, milliseconds: ms), txt));
}
}
if (mounted) setState(() => _lyrics = parsed);
}
}
} catch (_) {}
if (mounted) setState(() => _loadingLyrics = false);
}
String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
@override
void dispose() {
_uiTick?.cancel();
super.dispose();
}
@override
Widget build(BuildContext context) {
final song = widget.getSong();
if (song == null) return const SizedBox.shrink();
final pos = widget.getPos();
final dur = widget.getDur();
final playing = widget.getPlaying();
final shuffle = widget.getShuffle();
final loop = widget.getLoop();
final speed = widget.getSpeed();
final sleepMins = widget.getSleepMinutes();
final activeIdx = _lyrics.lastIndexWhere((l) => l.at <= pos);
return Scaffold(
backgroundColor: const Color(0xFF09090D),
appBar: AppBar(
backgroundColor: Colors.transparent,
leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30), onPressed: () => Navigator.pop(context)),
title: const Text('NOW PLAYING', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w800)),
centerTitle: true,
actions: [
PopupMenuButton<int?>(
icon: Icon(Icons.bedtime_rounded, color: sleepMins != null ? Colors.amber : Colors.white),
onSelected: widget.onSetSleep,
itemBuilder: (_) => const [
PopupMenuItem(value: null, child: Text('Sleep Timer: Off')),
PopupMenuItem(value: 15, child: Text('15 minutes')),
PopupMenuItem(value: 30, child: Text('30 minutes')),
PopupMenuItem(value: 60, child: Text('60 minutes')),
],
),
],
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [
Container(
height: 230,
decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(24)),
child: const Center(child: Icon(Icons.graphic_eq_rounded, size: 96, color: Colors.white70)),
),
const SizedBox(height: 20),
Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(song.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
Text(song.artist, style: const TextStyle(fontSize: 15, color: Colors.white60)),
],
),
),
TextButton(
onPressed: () {
final next = speed == 1.0 ? 1.25 : (speed == 1.25 ? 1.5 : (speed == 1.5 ? 0.75 : 1.0));
widget.onSetSpeed(next);
},
child: Text('${speed}x', style: const TextStyle(fontWeight: FontWeight.w800)),
),
],
),
const SizedBox(height: 12),
Slider(
value: dur.inMilliseconds > 0 ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0,
max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
onChanged: (v) => widget.player.seek(Duration(milliseconds: v.toInt())),
),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.white60)),
Text(_fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.white60)),
],
),
const SizedBox(height: 12),
Row(
mainAxisAlignment: MainAxisAlignment.spaceEvenly,
children: [
IconButton(
icon: Icon(Icons.shuffle_rounded, color: shuffle ? Colors.white : Colors.white38),
onPressed: widget.onToggleShuffle,
),
IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 36), onPressed: widget.onPrev),
FloatingActionButton.large(
backgroundColor: Colors.white,
foregroundColor: Colors.black,
onPressed: widget.onTogglePlay,
child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42),
),
IconButton(icon: const Icon(Icons.skip_next_rounded, size: 36), onPressed: widget.onNext),
IconButton(
icon: Icon(loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: loop != LoopMode.off ? Colors.white : Colors.white38),
onPressed: widget.onCycleLoop,
),
],
),
const SizedBox(height: 24),
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(color: const Color(0xFF1A1B2E), borderRadius: BorderRadius.circular(22)),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('LYRICS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
const SizedBox(height: 12),
if (_loadingLyrics)
const CircularProgressIndicator()
else if (_lyrics.isEmpty)
const Text('No synced lyrics found for this track.', style: TextStyle(color: Colors.white60))
else
...List.generate(_lyrics.length, (i) {
final active = i == activeIdx;
return Padding(
padding: const EdgeInsets.symmetric(vertical: 4),
child: Text(
_lyrics[i].text,
style: TextStyle(
fontSize: active ? 18 : 15,
fontWeight: active ? FontWeight.w900 : FontWeight.w600,
color: active ? Colors.white : Colors.white54,
),
),
);
}),
],
),
),
],
),
);
}
}



