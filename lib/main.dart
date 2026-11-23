import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(const TypeShiApp());
}

const List<Color> kAccentPalette = [
  Color(0xFFFFFFFF),
  Color(0xFFFF2E55),
  Color(0xFFA855F7),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF06B6D4),
];

const List<String> kAccentNames = ['Pure Ice', 'Crimson', 'Purple', 'Emerald', 'Gold', 'Cyan'];
const List<String> kFontNames = ['Modern Sans', 'Street Bold', 'Studio Mono'];
const List<String?> kFontFamilies = [null, 'sans-serif-condensed', 'monospace'];

const Map<String, List<double>> kEqPresets = {
  'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
  'Bass Boost': [6.5, 4.0, 0.0, 1.0, 2.5],
  'Hip-Hop': [5.5, 3.0, -1.0, 2.0, 4.5],
  'Vocal': [-1.5, 1.0, 4.5, 3.5, 1.0],
  'Midnight': [4.5, 2.0, -2.0, 1.5, 3.5],
};

class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.path,
    this.artPath,
    this.favorite = false,
    this.playCount = 0,
    this.durationMs = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final String? artPath;
  final bool favorite;
  final int playCount;
  final int durationMs;

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? artPath,
    bool? favorite,
    int? playCount,
    int? durationMs,
  }) =>
      Song(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        path: path,
        artPath: artPath ?? this.artPath,
        favorite: favorite ?? this.favorite,
        playCount: playCount ?? this.playCount,
        durationMs: durationMs ?? this.durationMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'path': path,
        'artPath': artPath,
        'favorite': favorite,
        'playCount': playCount,
        'durationMs': durationMs,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Unknown',
        artist: j['artist'] ?? 'Unknown Artist',
        album: j['album'] ?? '',
        path: j['path'] ?? '',
        artPath: j['artPath'],
        favorite: j['favorite'] ?? false,
        playCount: j['playCount'] ?? 0,
        durationMs: j['durationMs'] ?? 0,
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

class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({super.key, required this.color, required this.playing, this.size = 20});
  final Color color;
  final bool playing;
  final double size;

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = widget.playing ? _ctrl.value : 0.25;
        final h1 = 0.35 + 0.65 * math.sin(t * math.pi).abs();
        final h2 = 0.35 + 0.65 * math.cos(t * math.pi * 0.85).abs();
        final h3 = 0.35 + 0.65 * math.sin((1 - t) * math.pi).abs();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [h1, h2, h3].map((f) {
              return Container(
                width: widget.size * 0.2,
                height: widget.size * f,
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(4)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class TypeShiApp extends StatefulWidget {
  const TypeShiApp({super.key});

  @override
  State<TypeShiApp> createState() => _TypeShiAppState();
}

class _TypeShiAppState extends State<TypeShiApp> {
  int _accentIndex = 0;
  int _fontIndex = 0;
  Color? _dynamicAccent;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('accentIndex') ?? 0;
    final fIdx = prefs.getInt('fontIndex') ?? 0;
    if (mounted) {
      setState(() {
        if (idx >= 0 && idx < kAccentPalette.length) _accentIndex = idx;
        if (fIdx >= 0 && fIdx < kFontNames.length) _fontIndex = fIdx;
      });
    }
  }

  Future<void> _setAccent(int idx) async {
    setState(() {
      _accentIndex = idx;
      _dynamicAccent = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentIndex', idx);
  }

  Future<void> _setFont(int idx) async {
    setState(() => _fontIndex = idx);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontIndex', idx);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _dynamicAccent ?? kAccentPalette[_accentIndex];
    final family = kFontFamilies[_fontIndex];
    return MaterialApp(
      title: 'TYPE SHI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: family),
        colorScheme: ColorScheme.dark(
          primary: accent,
          onPrimary: Colors.black,
          surface: const Color(0xFF0E0E13),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: Colors.white12,
          thumbColor: accent,
          trackHeight: 3.5,
        ),
      ),
      home: HomeScreen(
        accent: accent,
        accentIndex: _accentIndex,
        fontIndex: _fontIndex,
        onSelectAccent: _setAccent,
        onSelectFont: _setFont,
        onDynamicAccent: (c) => setState(() => _dynamicAccent = c),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.accent,
    required this.accentIndex,
    required this.fontIndex,
    required this.onSelectAccent,
    required this.onSelectFont,
    required this.onDynamicAccent,
  });

  final Color accent;
  final int accentIndex;
  final int fontIndex;
  final Future<void> Function(int) onSelectAccent;
  final Future<void> Function(int) onSelectFont;
  final void Function(Color?) onDynamicAccent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AndroidEqualizer _eq = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_eq]),
  );
  final List<Song> _songs = [];
  final List<Playlist> _playlists = [];
  final Set<String> _selectedIds = {};
  List<Song> _queue = [];
  int _index = -1;
  int _tab = 0;
  int _filterTab = 0;
  int _browseMode = 0;
  bool _enableBrowseTabs = false;
  bool _dynamicCoverColor = true;
  bool _showMiniLyric = true;
  bool _slowedReverb = false;
  bool _sortAZ = false;
  int _crossfadeSec = 0;
  int _totalSecondsListened = 0;
  String _eqPreset = 'Flat';
  List<double> _eqGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  String _query = '';
  String _bannerTitle = 'TYPE SHI';
  String? _bgPath;
  bool _playing = false;
  bool _shuffle = false;
  LoopMode _loop = LoopMode.off;
  double _speed = 1.0;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  Duration? _loopA;
  Duration? _loopB;
  Timer? _sleepTimer;
  Timer? _statTimer;
  int? _sleepMinutes;
  bool _crossfading = false;
  List<LyricLine> _miniLyrics = [];
  String? _miniLyricsSongId;

  Song? get _current => (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initStorageAndStreams();
  }

  Future<void> _initStorageAndStreams() async {
    _statTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playing) {
        _totalSecondsListened += 5;
        SharedPreferences.getInstance().then((p) => p.setInt('totalSec', _totalSecondsListened));
      }
    });

    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
      if (_loopA != null && _loopB != null && _loopB! > _loopA! && p >= _loopB!) {
        _player.seek(_loopA!);
      }
      if (_crossfadeSec > 0 &&
          !_crossfading &&
          _dur.inSeconds > _crossfadeSec + 2 &&
          (_dur - p).inMilliseconds <= _crossfadeSec * 1000 &&
          (_dur - p).inMilliseconds > 200) {
        _triggerCrossfade();
      }
    });

    _player.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _dur = d);
      if (_current != null && _current!.durationMs == 0 && d.inMilliseconds > 0) {
        final updated = _current!.copyWith(durationMs: d.inMilliseconds);
        _queue[_index] = updated;
        final idx = _songs.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) _songs[idx] = updated;
        _saveData();
      }
    });

    _player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
      if (st.processingState == ProcessingState.completed && _loop != LoopMode.one && !_crossfading) {
        _next();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final rawSongs = prefs.getString('songs');
    if (rawSongs != null && rawSongs.isNotEmpty) {
      final list = jsonDecode(rawSongs) as List;
      _songs.addAll(
        list.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).where((s) => File(s.path).existsSync()),
      );
    }
    final rawPl = prefs.getString('playlists');
    if (rawPl != null && rawPl.isNotEmpty) {
      final list = jsonDecode(rawPl) as List;
      _playlists.addAll(list.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))));
    }
    final bg = prefs.getString('bgPath');
    if (bg != null && File(bg).existsSync()) _bgPath = bg;
    final savedBanner = prefs.getString('bannerTitle');
    if (savedBanner != null && savedBanner.isNotEmpty) _bannerTitle = savedBanner;

    _enableBrowseTabs = prefs.getBool('enableBrowseTabs') ?? false;
    _dynamicCoverColor = prefs.getBool('dynamicCoverColor') ?? true;
    _showMiniLyric = prefs.getBool('showMiniLyric') ?? true;
    _crossfadeSec = prefs.getInt('crossfadeSec') ?? 0;
    _totalSecondsListened = prefs.getInt('totalSec') ?? 0;
    _eqPreset = prefs.getString('eqPreset') ?? 'Flat';
    final rawGains = prefs.getString('eqGains');
    if (rawGains != null) {
      _eqGains = (jsonDecode(rawGains) as List).map((e) => (e as num).toDouble()).toList();
    }
    await _applyEq();
    if (mounted) setState(() {});
  }

  Future<void> _applyEq() async {
    try {
      final params = await _eq.parameters;
      final bands = params.bands;
      for (int i = 0; i < bands.length && i < _eqGains.length; i++) {
        await bands[i].setGain(_eqGains[i]);
      }
      await _eq.setEnabled(_eqPreset != 'Flat');
    } catch (_) {}
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songs', jsonEncode(_songs.map((e) => e.toJson()).toList()));
    await prefs.setString('playlists', jsonEncode(_playlists.map((e) => e.toJson()).toList()));
    await prefs.setString('bannerTitle', _bannerTitle);
    await prefs.setBool('enableBrowseTabs', _enableBrowseTabs);
    await prefs.setBool('dynamicCoverColor', _dynamicCoverColor);
    await prefs.setBool('showMiniLyric', _showMiniLyric);
    await prefs.setInt('crossfadeSec', _crossfadeSec);
    await prefs.setString('eqPreset', _eqPreset);
    await prefs.setString('eqGains', jsonEncode(_eqGains));
    if (_bgPath != null) {
      await prefs.setString('bgPath', _bgPath!);
    } else {
      await prefs.remove('bgPath');
    }
  }

  String _cleanText(String raw) {
    final noParens = raw.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\[[^\]]*\]'), '');
    return noParens
        .replaceAll(RegExp(r'\.(mp3|m4a|wav|flac|ogg|aac)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _importFileList(List<File> rawFiles) async {
    if (rawFiles.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    int added = 0;
    for (final srcFile in rawFiles) {
      if (!srcFile.existsSync()) continue;
      final fileName = srcFile.uri.pathSegments.isNotEmpty ? srcFile.uri.pathSegments.last : 'track.mp3';
      final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '.mp3';
      final stamp = DateTime.now().microsecondsSinceEpoch + added;
      final dest = '${dir.path}/track_$stamp$ext';
      final copied = await srcFile.copy(dest);

      String title = '';
      String artist = '';
      String album = '';
      String? embeddedArt;
      try {
        final meta = readMetadata(copied, getImage: true);
        title = (meta.title ?? '').trim();
        artist = (meta.artist ?? '').trim();
        album = (meta.album ?? '').trim();
        if (meta.pictures.isNotEmpty) {
          final artFile = File('${dir.path}/art_$stamp.jpg');
          await artFile.writeAsBytes(meta.pictures.first.bytes);
          embeddedArt = artFile.path;
        }
      } catch (_) {}

      final cleanName = _cleanText(fileName);
      final parts = cleanName.split(' - ');
      if (title.isEmpty) {
        title = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : cleanName;
      }
      if (artist.isEmpty) {
        artist = parts.length > 1 ? parts.first.trim() : (album.isNotEmpty ? album : 'Unknown Artist');
      }

      _songs.add(Song(
        id: 's_$stamp',
        title: title,
        artist: artist,
        album: album,
        path: dest,
        artPath: embeddedArt,
      ));
      added++;
    }
    await _saveData();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $added track(s)')));
  }

  Future<void> _importSongs() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final list = files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    await _importFileList(list);
  }

  Future<void> _importFolder() async {
    final folderPath = await FilePicker.getDirectoryPath();
    if (folderPath == null) return;
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return;
    final exts = {'.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac'};
    final found = dir.listSync(recursive: true).whereType<File>().where((f) {
      final lower = f.path.toLowerCase();
      return exts.any(lower.endsWith);
    }).toList();
    await _importFileList(found);
  }

  Future<void> _pickWallpaper() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final src = files.isNotEmpty ? files.first.path : null;
    if (src == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(src).copy(dest);
    _bgPath = dest;
    await _saveData();
    if (mounted) setState(() {});
  }

  Future<void> _setSongArt(Song s) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final src = files.isNotEmpty ? files.first.path : null;
    if (src == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/art_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(src).copy(dest);
    final updated = s.copyWith(artPath: dest);
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
    if (_current?.id == s.id) await _extractCoverColor(updated);
    if (mounted) setState(() {});
  }

  Future<void> _extractCoverColor(Song s) async {
    if (!_dynamicCoverColor || s.artPath == null || !File(s.artPath!).existsSync()) {
      widget.onDynamicAccent(null);
      return;
    }
    try {
      final bytes = await File(s.artPath!).readAsBytes();
      final codec = await instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ImageByteFormat.rawRgba);
      if (data == null) return;
      int rSum = 0, gSum = 0, bSum = 0, count = 0;
      for (int i = 0; i < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i);
        final g = data.getUint8(i + 1);
        final b = data.getUint8(i + 2);
        if (r + g + b > 90 && r + g + b < 680) {
          rSum += r;
          gSum += g;
          bSum += b;
          count++;
        }
      }
      if (count > 0) {
        final hsl = HSLColor.fromColor(Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count));
        final vibrant = hsl.withSaturation((hsl.saturation + 0.25).clamp(0.45, 0.95)).withLightness(0.62).toColor();
        widget.onDynamicAccent(vibrant);
      }
    } catch (_) {}
  }

  Future<void> _loadMiniLyrics(Song s) async {
    if (_miniLyricsSongId == s.id) return;
    _miniLyricsSongId = s.id;
    _miniLyrics = [];
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('lyrics_${s.id}');
    if (cached != null && cached.isNotEmpty) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final synced = (data['synced'] ?? '').toString();
      final rx = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');
      final parsed = <LyricLine>[];
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
      if (mounted) setState(() => _miniLyrics = parsed);
    }
  }

  Future<void> _toggleFavorite(Song s) async {
    HapticFeedback.lightImpact();
    final updated = s.copyWith(favorite: !s.favorite);
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
    if (mounted) setState(() {});
  }

  void _playNextInQueue(Song s) {
    HapticFeedback.mediumImpact();
    if (_queue.isEmpty) {
      _playFromQueue([s], 0);
      return;
    }
    final insertAt = (_index + 1).clamp(0, _queue.length);
    setState(() => _queue.insert(insertAt, s));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing "${s.title}" next'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _triggerCrossfade() async {
    if (_queue.length <= 1) return;
    _crossfading = true;
    try {
      for (int i = 4; i >= 1; i--) {
        await _player.setVolume(i / 5.0);
        await Future.delayed(Duration(milliseconds: (_crossfadeSec * 150).clamp(150, 600)));
      }
      await _next();
      for (int i = 1; i <= 5; i++) {
        await _player.setVolume(i / 5.0);
        await Future.delayed(Duration(milliseconds: (_crossfadeSec * 150).clamp(150, 600)));
      }
    } finally {
      await _player.setVolume(1.0);
      _crossfading = false;
    }
  }

  Future<void> _playFromQueue(List<Song> queue, int startIndex, {bool shuffleStart = false}) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) return;
    final list = List<Song>.from(queue);
    if (shuffleStart && list.length > 1) {
      list.shuffle();
      _shuffle = true;
    }
    final target = list[startIndex];
    final bumped = target.copyWith(playCount: target.playCount + 1);
    list[startIndex] = bumped;
    final mainIdx = _songs.indexWhere((e) => e.id == target.id);
    if (mainIdx >= 0) _songs[mainIdx] = bumped;

    setState(() {
      _queue = list;
      _index = startIndex;
      _pos = Duration.zero;
      _dur = Duration.zero;
      _loopA = null;
      _loopB = null;
    });
    await _saveData();
    await _extractCoverColor(bumped);
    await _loadMiniLyrics(bumped);
    await _player.setVolume(1.0);
    await _player.setFilePath(_queue[_index].path);
    await _player.setSpeed(_slowedReverb ? 0.85 : _speed);
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

  Future<void> _seekBy(int seconds) async {
    if (_dur.inMilliseconds <= 0) return;
    final nextMs = (_pos.inMilliseconds + seconds * 1000).clamp(0, _dur.inMilliseconds);
    await _player.seek(Duration(milliseconds: nextMs));
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

  Future<void> _editTrackDialog(Song s) async {
    final titleCtrl = TextEditingController(text: s.title);
    final artistCtrl = TextEditingController(text: s.artist == 'Unknown Artist' ? '' : s.artist);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        title: const Text('Edit Track Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Song Title')),
            const SizedBox(height: 12),
            TextField(controller: artistCtrl, decoration: const InputDecoration(labelText: 'Artist Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    String newTitle = titleCtrl.text.trim();
    String newArtist = artistCtrl.text.trim();
    if (newTitle.contains(' - ') && newArtist.isEmpty) {
      final parts = newTitle.split(' - ');
      newArtist = parts.first.trim();
      newTitle = parts.sublist(1).join(' - ').trim();
    }
    if (newTitle.isEmpty) return;
    if (newArtist.isEmpty) newArtist = 'Unknown Artist';
    final updated = s.copyWith(title: newTitle, artist: newArtist);
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
    if (mounted) setState(() {});
  }

    Future<void> _batchFavorite() async {
    for (int i = 0; i < _songs.length; i++) {
      if (_selectedIds.contains(_songs[i].id)) _songs[i] = _songs[i].copyWith(favorite: true);
    }
    setState(() => _selectedIds.clear());
    await _saveData();
  }

  Future<void> _batchAddToPlaylist() async {
    final name = await _promptText('Playlist name');
    if (name == null || name.isEmpty) return;
    final existing = _playlists.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
    final target = existing.isNotEmpty ? existing.first : Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: []);
    if (existing.isEmpty) _playlists.add(target);
    for (final id in _selectedIds) {
      if (!target.songIds.contains(id)) target.songIds.add(id);
    }
    setState(() => _selectedIds.clear());
    await _saveData();
  }

  Future<void> _batchDelete() async {
    for (final id in _selectedIds) {
      final s = _songs.where((e) => e.id == id).firstOrNull;
      if (s != null && File(s.path).existsSync()) await File(s.path).delete();
      _songs.removeWhere((e) => e.id == id);
    }
    setState(() => _selectedIds.clear());
    await _saveData();
  }

  Future<void> _removeDuplicates() async {
    final seen = <String>{};
    final dupIds = <String>[];
    for (final s in _songs) {
      final key = '${s.title.toLowerCase().trim()}|${s.artist.toLowerCase().trim()}';
      if (seen.contains(key)) { dupIds.add(s.id); } else { seen.add(key); }
    }
    if (dupIds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No duplicate tracks found!')));
      return;
    }
    for (final id in dupIds) {
      final s = _songs.where((e) => e.id == id).firstOrNull;
      if (s != null && File(s.path).existsSync()) await File(s.path).delete();
      _songs.removeWhere((e) => e.id == id);
    }
    await _saveData();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${dupIds.length} duplicate track(s)'))); }
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lyricMap = <String, String>{};
      for (final k in prefs.getKeys()) {
        if (k.startsWith('lyrics_')) { final v = prefs.getString(k); if (v != null) lyricMap[k] = v; }
      }
      final payload = jsonEncode({'bannerTitle': _bannerTitle, 'songs': _songs.map((e) => e.toJson()).toList(), 'playlists': _playlists.map((e) => e.toJson()).toList(), 'lyrics': lyricMap});
      final dir = await getApplicationDocumentsDirectory();
      final out = File('${dir.path}/typeshi_backup_${DateTime.now().millisecondsSinceEpoch}.typeshi');
      await out.writeAsBytes(gzip.encode(utf8.encode(payload)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved: ${out.path}'), duration: const Duration(seconds: 4)));
    } catch (_) {}
  }

  Future<void> _restoreBackup() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      final src = files.isNotEmpty ? files.first.path : null;
      if (src == null) return;
      final data = jsonDecode(utf8.decode(gzip.decode(await File(src).readAsBytes()))) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      if (data['bannerTitle'] is String) _bannerTitle = data['bannerTitle'];
      if (data['playlists'] is List) { _playlists..clear()..addAll((data['playlists'] as List).map((e) => Playlist.fromJson(Map<String, dynamic>.from(e)))); }
      if (data['lyrics'] is Map) { for (final entry in (data['lyrics'] as Map).entries) { await prefs.setString(entry.key.toString(), entry.value.toString()); } }
      await _saveData();
      if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored!'))); }
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid backup file'))); }
  }

  void _openEqSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121218),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          const bands = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Row(children: [Text('5-BAND EQUALIZER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: widget.accent)), const Spacer(), Text(_eqPreset, style: const TextStyle(fontSize: 12, color: Colors.white60))]),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kEqPresets.keys.map((name) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: _eqPreset == name,
                          onSelected: (_) async { _eqPreset = name; _eqGains = List<double>.from(kEqPresets[name]!); await _applyEq(); setState(() {}); setSheetState(() {}); },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (i) {
                    return Column(
                      children: [
                        Text('${_eqGains[i].toStringAsFixed(1)}dB', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                        SizedBox(height: 130, child: RotatedBox(quarterTurns: 3, child: Slider(min: -10, max: 10, value: _eqGains[i].clamp(-10.0, 10.0), onChanged: (v) async { _eqPreset = 'Custom'; _eqGains[i] = v; await _applyEq(); setState(() {}); setSheetState(() {}); }))),
                        Text(bands[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openMostPlayedAndWrappedSheet() {
    final topPlayed = _songs.where((s) => s.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final totalPlays = _songs.fold<int>(0, (sum, s) => sum + s.playCount);
    final minsListened = (_totalSecondsListened / 60).round();
    final artistCounts = <String, int>{};
    for (final s in _songs) {
      if (s.playCount > 0) {
        artistCounts[s.artist] = (artistCounts[s.artist] ?? 0) + s.playCount;
      }
    }
    String topArtist = 'None yet';
    int bestArtistPlays = 0;
    artistCounts.forEach((k, v) {
      if (v > bestArtistPlays) {
        bestArtistPlays = v;
        topArtist = k;
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121218),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Text('WRAPPED & MOST PLAYED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: widget.accent)),
                const Spacer(),
                Text('$totalPlays plays', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MINUTES LISTENED', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('$minsListened min', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: widget.accent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOP ARTIST', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(topArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: widget.accent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: topPlayed.isEmpty
                ? const Center(child: Text('Play some songs first to see your top tracks!', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: topPlayed.length,
                    itemBuilder: (_, i) {
                      final tp = topPlayed[i];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: widget.accent.withValues(alpha: 0.18), child: Text('#${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: widget.accent, fontSize: 13))),
                        title: Text(tp.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(tp.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                          child: Text('${tp.playCount} plays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: widget.accent)),
                        ),
                        onTap: () { Navigator.pop(ctx); _playFromQueue(topPlayed, i); },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openNowPlaying() {
    if (_current == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NowPlayingSheet(
        accent: widget.accent,
        getSong: () => _current,
        getQueue: () => _queue,
        getQueueIndex: () => _index,
        getPlaying: () => _playing,
        getPos: () => _pos,
        getDur: () => _dur,
        getShuffle: () => _shuffle,
        getLoop: () => _loop,
        getSpeed: () => _speed,
        getSlowedReverb: () => _slowedReverb,
        getSleepMinutes: () => _sleepMinutes,
        getLoopA: () => _loopA,
        getLoopB: () => _loopB,
        player: _player,
        onTogglePlay: () => _playing ? _player.pause() : _player.play(),
        onToggleFavorite: () {
          if (_current != null) _toggleFavorite(_current!);
        },
        onNext: _next,
        onPrev: _prev,
        onSeekBy: _seekBy,
        onToggleSlowedReverb: () async {
          _slowedReverb = !_slowedReverb;
          final targetSpeed = _slowedReverb ? 0.85 : 1.0;
          await _player.setSpeed(targetSpeed);
          if (_slowedReverb) {
            _eqPreset = 'Midnight';
            _eqGains = List<double>.from(kEqPresets['Midnight']!);
          } else {
            _eqPreset = 'Flat';
            _eqGains = List<double>.from(kEqPresets['Flat']!);
          }
          await _applyEq();
          setState(() => _speed = targetSpeed);
        },
        onOpenEq: _openEqSheet,
        onSetLoopA: (d) => setState(() => _loopA = d),
        onSetLoopB: (d) => setState(() => _loopB = d),
        onClearAB: () => setState(() {
          _loopA = null;
          _loopB = null;
        }),
        onJumpToQueueIndex: (idx) => _playFromQueue(_queue, idx),
        onReorderQueue: (oldIdx, newIdx) {
          setState(() {
            if (newIdx > oldIdx) newIdx -= 1;
            final item = _queue.removeAt(oldIdx);
            _queue.insert(newIdx, item);
            if (_index == oldIdx) {
              _index = newIdx;
            } else if (oldIdx < _index && newIdx >= _index) {
              _index -= 1;
            } else if (oldIdx > _index && newIdx <= _index) {
              _index += 1;
            }
          });
        },
        onToggleShuffle: () => setState(() => _shuffle = !_shuffle),
        onCycleLoop: () async {
          final next = _loop == LoopMode.off ? LoopMode.all : (_loop == LoopMode.all ? LoopMode.one : LoopMode.off);
          await _player.setLoopMode(next);
          setState(() => _loop = next);
        },
        onSetSpeed: (s) async {
          await _player.setSpeed(s);
          setState(() {
            _speed = s;
            _slowedReverb = false;
          });
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

  Widget _buildArtBox(Song s, {double size = 48, double radius = 12, bool active = false}) {
    final hasArt = s.artPath != null && File(s.artPath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: active ? widget.accent.withValues(alpha: 0.75) : Colors.white10),
        image: hasArt ? DecorationImage(image: FileImage(File(s.artPath!)), fit: BoxFit.cover) : null,
      ),
      child: active
          ? Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: hasArt ? 0.45 : 0.0),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(child: AnimatedEqualizer(color: widget.accent, playing: _playing, size: size * 0.44)),
            )
          : (hasArt ? null : Icon(Icons.music_note_rounded, color: Colors.white70, size: size * 0.48)),
    );
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _statTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    var filtered = _songs.where((s) {
      if (_filterTab == 1 && !s.favorite) return false;
      if (_query.isEmpty) return true;
      return s.title.toLowerCase().contains(_query) ||
          s.artist.toLowerCase().contains(_query) ||
          s.album.toLowerCase().contains(_query);
    }).toList();
    if (_sortAZ) {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    final progress = _dur.inMilliseconds > 0 ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final activeMiniLyric = _showMiniLyric && _miniLyrics.isNotEmpty
        ? _miniLyrics.lastWhere((l) => l.at <= _pos, orElse: () => _miniLyrics.first).text
        : '';

    final artistGroups = <String, List<Song>>{};
    final albumGroups = <String, List<Song>>{};
    for (final s in filtered) {
      artistGroups.putIfAbsent(s.artist.isEmpty ? 'Unknown Artist' : s.artist, () => []).add(s);
      albumGroups.putIfAbsent(s.album.isEmpty ? 'Singles & Loose Tracks' : s.album, () => []).add(s);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.85),
                radius: 1.2,
                colors: [accent.withValues(alpha: 0.14), Colors.black],
              ),
            ),
          ),
        ),
        if (_bgPath != null)
          Positioned.fill(
            child: Opacity(opacity: 0.25, child: Image.file(File(_bgPath!), fit: BoxFit.cover)),
          ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _selecting
              ? AppBar(
                  backgroundColor: const Color(0xFF14141C),
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _selectedIds.clear()),
                  ),
                  title: Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w800)),
                  actions: [
                    IconButton(
                      tooltip: 'Like Selected',
                      icon: Icon(Icons.favorite_rounded, color: accent),
                      onPressed: _batchFavorite,
                    ),
                    IconButton(
                      tooltip: 'Add to Playlist',
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: _batchAddToPlaylist,
                    ),
                    IconButton(
                      tooltip: 'Delete Selected',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: _batchDelete,
                    ),
                  ],
                )
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Row(
                    children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _bannerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.8, fontSize: 19),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Scan Music Folder',
                      icon: Icon(Icons.create_new_folder_rounded, color: accent),
                      onPressed: _importFolder,
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                      onPressed: _importSongs,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add MP3s', style: TextStyle(fontWeight: FontWeight.w800)),
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
                          hintText: 'Search songs, artists, or albums...',
                          prefixIcon: Icon(Icons.search_rounded, color: accent.withValues(alpha: 0.8)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    if (_songs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text('All (${_songs.length})'),
                                selected: _filterTab == 0 && _browseMode == 0,
                                onSelected: (_) => setState(() {
                                  _filterTab = 0;
                                  _browseMode = 0;
                                }),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Liked (${_songs.where((s) => s.favorite).length})'),
                                selected: _filterTab == 1 && _browseMode == 0,
                                onSelected: (_) => setState(() {
                                  _filterTab = 1;
                                  _browseMode = 0;
                                }),
                              ),
                              if (_enableBrowseTabs) ...[
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Artists'),
                                  selected: _browseMode == 1,
                                  onSelected: (_) => setState(() => _browseMode = 1),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Albums'),
                                  selected: _browseMode == 2,
                                  onSelected: (_) => setState(() => _browseMode = 2),
                                ),
                              ],
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: _sortAZ ? 'Sorted A-Z' : 'Sort A-Z',
                                icon: Icon(Icons.sort_by_alpha_rounded, color: _sortAZ ? accent : Colors.white54),
                                onPressed: () => setState(() => _sortAZ = !_sortAZ),
                              ),
                              IconButton(
                                tooltip: 'Shuffle All',
                                icon: Icon(Icons.shuffle_rounded, color: accent),
                                onPressed: filtered.isEmpty ? null : () => _playFromQueue(filtered, 0, shuffleStart: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: _browseMode == 1
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                              children: artistGroups.entries.map((e) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.2), child: Icon(Icons.person_rounded, color: accent)),
                                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text('${e.value.length} track(s)', style: const TextStyle(color: Colors.white60)),
                                    trailing: const Icon(Icons.play_arrow_rounded),
                                    onTap: () => _playFromQueue(e.value, 0),
                                  ),
                                );
                              }).toList(),
                            )
                          : _browseMode == 2
                              ? ListView(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                                  children: albumGroups.entries.map((e) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        leading: _buildArtBox(e.value.first, size: 44, radius: 10),
                                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        subtitle: Text('${e.value.length} track(s)', style: const TextStyle(color: Colors.white60)),
                                        trailing: const Icon(Icons.play_arrow_rounded),
                                        onTap: () => _playFromQueue(e.value, 0),
                                      ),
                                    );
                                  }).toList(),
                                )
                              : filtered.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.library_music_rounded, size: 58, color: accent.withValues(alpha: 0.5)),
                                          const SizedBox(height: 12),
                                          Text(_filterTab == 1 ? 'No Liked Tracks Yet' : 'Your Library is Empty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 6),
                                          Text(_filterTab == 1 ? 'Swipe right or tap the heart on any song' : 'Tap + Add MP3s or the Folder icon to import music', style: const TextStyle(color: Colors.white60)),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                                      itemCount: filtered.length,
                                      itemBuilder: (ctx, i) {
                                        final s = filtered[i];
                                        final active = _current?.id == s.id;
                                        final isSelected = _selectedIds.contains(s.id);
                                        return Dismissible(
                                          key: ValueKey('swipe_${s.id}'),
                                          confirmDismiss: (dir) async {
                                            if (dir == DismissDirection.startToEnd) {
                                              await _toggleFavorite(s);
                                            } else {
                                              _playNextInQueue(s);
                                            }
                                            return false;
                                          },
                                          background: Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.only(left: 20),
                                            alignment: Alignment.centerLeft,
                                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
                                            child: Icon(Icons.favorite_rounded, color: accent),
                                          ),
                                          secondaryBackground: Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.only(right: 20),
                                            alignment: Alignment.centerRight,
                                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
                                            child: const Icon(Icons.queue_play_next_rounded, color: Colors.white),
                                          ),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? accent.withValues(alpha: 0.22)
                                                  : (active ? accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.045)),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: (isSelected || active) ? accent.withValues(alpha: 0.55) : Colors.white10),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                                              leading: isSelected
                                                  ? CircleAvatar(backgroundColor: accent, child: const Icon(Icons.check_rounded, color: Colors.black))
                                                  : _buildArtBox(s, active: active),
                                              title: Text(
                                                s.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontWeight: FontWeight.w800, color: active ? accent : Colors.white),
                                              ),
                                              subtitle: Text(
                                                s.artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                                              ),
                                              trailing: _selecting
                                                  ? null
                                                  : Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(s.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: s.favorite ? accent : Colors.white38, size: 20),
                                                          onPressed: () => _toggleFavorite(s),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                                          onSelected: (v) async {
                                                            if (v == 'next') {
                                                              _playNextInQueue(s);
                                                            } else if (v == 'pl') {
                                                              final name = await _promptText('Playlist name');
                                                              if (name != null && name.isNotEmpty) {
                                                                final existing = _playlists.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
                                                                if (existing.isNotEmpty) {
                                                                  if (!existing.first.songIds.contains(s.id)) existing.first.songIds.add(s.id);
                                                                } else {
                                                                  _playlists.add(Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: [s.id]));
                                                                }
                                                                await _saveData();
                                                                setState(() {});
                                                              }
                                                            } else if (v == 'ed') {
                                                              await _editTrackDialog(s);
                                                            } else if (v == 'art') {
                                                              await _setSongArt(s);
                                                            } else if (v == 'rm') {
                                                              _songs.removeWhere((e) => e.id == s.id);
                                                              if (File(s.path).existsSync()) await File(s.path).delete();
                                                              await _saveData();
                                                              setState(() {});
                                                            }
                                                          },
                                                          itemBuilder: (ctx) => const [
                                                            PopupMenuItem(value: 'next', child: Text('Play Next')),
                                                            PopupMenuItem(value: 'pl', child: Text('Add to playlist')),
                                                            PopupMenuItem(value: 'ed', child: Text('Edit Title & Artist')),
                                                            PopupMenuItem(value: 'art', child: Text('Set Cover Art')),
                                                            PopupMenuItem(value: 'rm', child: Text('Delete')),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                              onLongPress: () {
                                                HapticFeedback.mediumImpact();
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedIds.remove(s.id);
                                                  } else {
                                                    _selectedIds.add(s.id);
                                                  }
                                                });
                                              },
                                              onTap: () {
                                                if (_selecting) {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedIds.remove(s.id);
                                                    } else {
                                                      _selectedIds.add(s.id);
                                                    }
                                                  });
                                                } else {
                                                  _playFromQueue(filtered, i);
                                                }
                                              },
                                            ),
                                          ),
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
                              const Expanded(child: Text('Playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                                onPressed: () async {
                                  final name = await _promptText('New playlist');
                                  if (name != null && name.isNotEmpty) {
                                    _playlists.add(Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: []));
                                    await _saveData();
                                    setState(() {});
                                  }
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _playlists.length,
                            itemBuilder: (ctx, i) {
                              final pl = _playlists[i];
                              final plSongs = pl.songIds.map((id) => _songs.where((s) => s.id == id).firstOrNull).whereType<Song>().toList();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.2), child: Icon(Icons.queue_music_rounded, color: accent)),
                                  title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${plSongs.length} songs', style: const TextStyle(color: Colors.white60)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    onPressed: () async {
                                      _playlists.removeAt(i);
                                      await _saveData();
                                      setState(() {});
                                    },
                                  ),
                                  onTap: plSongs.isEmpty ? null : () => _playFromQueue(plSongs, 0),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text('Customize TYPE SHI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 18),
                        const Text('ACCENT COLOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(kAccentPalette.length, (i) {
                            final c = kAccentPalette[i];
                            final selected = widget.accentIndex == i;
                            return GestureDetector(
                              onTap: () => widget.onSelectAccent(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? c.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: selected ? c : Colors.white12, width: selected ? 2 : 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 16, height: 16, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(kAccentNames[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        const Text('APP FONT STYLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: List.generate(kFontNames.length, (i) {
                            return ChoiceChip(
                              label: Text(kFontNames[i], style: TextStyle(fontFamily: kFontFamilies[i])),
                              selected: widget.fontIndex == i,
                              onSelected: (_) => widget.onSelectFont(i),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        const Text('BACKGROUND WALLPAPER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 10),
                        ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(Icons.wallpaper_rounded, color: accent),
                          title: const Text('Set Custom Background Wallpaper'),
                          onTap: _pickWallpaper,
                        ),
                        if (_bgPath != null) ...[
                          const SizedBox(height: 10),
                          ListTile(
                            tileColor: Colors.white.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: const Icon(Icons.hide_image_rounded, color: Colors.white70),
                            title: const Text('Remove Background Wallpaper'),
                            onTap: () async {
                              _bgPath = null;
                              await _saveData();
                              setState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 22),
                        const Text('EXPERIENCE & AUDIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Artist & Album Tabs in Library', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Toggle extra Artists & Albums filter chips'),
                          value: _enableBrowseTabs,
                          onChanged: (v) async {
                            setState(() {
                              _enableBrowseTabs = v;
                              if (!v) _browseMode = 0;
                            });
                            await _saveData();
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Dynamic Cover Color Glow', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Match accent color to current song cover'),
                          value: _dynamicCoverColor,
                          onChanged: (v) async {
                            setState(() => _dynamicCoverColor = v);
                            if (!v) {
                              widget.onDynamicAccent(null);
                            } else if (_current != null) {
                              await _extractCoverColor(_current!);
                            }
                            await _saveData();
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Live Lyric Line on Mini-Player', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Show current synced lyric line while browsing'),
                          value: _showMiniLyric,
                          onChanged: (v) async {
                            setState(() => _showMiniLyric = v);
                            await _saveData();
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(Icons.blur_on_rounded, color: accent),
                          title: Text('Smooth Crossfade: ${_crossfadeSec == 0 ? "Off" : "${_crossfadeSec}s"}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Tap to cycle 0s / 2s / 4s DJ fade'),
                          onTap: () async {
                            setState(() => _crossfadeSec = _crossfadeSec == 0 ? 2 : (_crossfadeSec == 2 ? 4 : 0));
                            await _saveData();
                          },
                        ),
                        const SizedBox(height: 22),
                        const Text('STATS & LIBRARY TOOLS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 10),
                        ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(Icons.bar_chart_rounded, color: accent),
                          title: const Text('Most Played & Wrapped Stats', style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('View top tracks, minutes listened & top artist'),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                          onTap: _openMostPlayedAndWrappedSheet,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(Icons.cleaning_services_rounded, color: accent),
                          title: const Text('Find & Remove Duplicate Tracks', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: _removeDuplicates,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _exportBackup,
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: const Text('Export Backup'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _restoreBackup,
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Restore Backup'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('APP HEADER TITLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                        const SizedBox(height: 10),
                        ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(Icons.edit_rounded, color: accent),
                          title: Text(_bannerTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('Tap to customize top header banner'),
                          onTap: () async {
                            final name = await _promptText('App Header Title', initial: _bannerTitle);
                            if (name != null && name.isNotEmpty) {
                              setState(() => _bannerTitle = name);
                              await _saveData();
                            }
                          },
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withValues(alpha: 0.38)),
                            ),
                            child: Text(
                              'made by Aakas',
                              style: TextStyle(fontSize: 13, letterSpacing: 1.6, color: accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_current != null)
                GestureDetector(
                  onTap: _openNowPlaying,
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -250) {
                      HapticFeedback.lightImpact();
                      _next();
                    } else if (v > 250) {
                      HapticFeedback.lightImpact();
                      _prev();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181822).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                          child: Row(
                            children: [
                              _buildArtBox(_current!, size: 42, radius: 10, active: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(
                                      activeMiniLyric.isNotEmpty ? activeMiniLyric : _current!.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: activeMiniLyric.isNotEmpty ? accent : Colors.white60),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, size: 34, color: accent),
                                onPressed: () => _playing ? _player.pause() : _player.play(),
                              ),
                              IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: _next),
                            ],
                          ),
                        ),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ],
                    ),
                  ),
                ),
              NavigationBar(
                backgroundColor: const Color(0xFF0A0A0E),
                indicatorColor: accent.withValues(alpha: 0.22),
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
    required this.accent,
    required this.getSong,
    required this.getQueue,
    required this.getQueueIndex,
    required this.getPlaying,
    required this.getPos,
    required this.getDur,
    required this.getShuffle,
    required this.getLoop,
    required this.getSpeed,
    required this.getSlowedReverb,
    required this.getSleepMinutes,
    required this.getLoopA,
    required this.getLoopB,
    required this.player,
    required this.onTogglePlay,
    required this.onToggleFavorite,
    required this.onNext,
    required this.onPrev,
    required this.onSeekBy,
    required this.onToggleSlowedReverb,
    required this.onOpenEq,
    required this.onSetLoopA,
    required this.onSetLoopB,
    required this.onClearAB,
    required this.onJumpToQueueIndex,
    required this.onReorderQueue,
    required this.onToggleShuffle,
    required this.onCycleLoop,
    required this.onSetSpeed,
    required this.onSetSleep,
  });

  final Color accent;
  final Song? Function() getSong;
  final List<Song> Function() getQueue;
  final int Function() getQueueIndex;
  final bool Function() getPlaying;
  final Duration Function() getPos;
  final Duration Function() getDur;
  final bool Function() getShuffle;
  final LoopMode Function() getLoop;
  final double Function() getSpeed;
  final bool Function() getSlowedReverb;
  final int? Function() getSleepMinutes;
  final Duration? Function() getLoopA;
  final Duration? Function() getLoopB;
  final AudioPlayer player;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Future<void> Function(int) onSeekBy;
  final Future<void> Function() onToggleSlowedReverb;
  final VoidCallback onOpenEq;
  final void Function(Duration) onSetLoopA;
  final void Function(Duration) onSetLoopB;
  final VoidCallback onClearAB;
  final Future<void> Function(int) onJumpToQueueIndex;
  final void Function(int, int) onReorderQueue;
  final VoidCallback onToggleShuffle;
  final Future<void> Function() onCycleLoop;
  final Future<void> Function(double) onSetSpeed;
  final void Function(int?) onSetSleep;

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> with TickerProviderStateMixin {
  List<LyricLine> _lyrics = [];
  String _plainLyrics = '';
  bool _loadingLyrics = false;
  bool _fullScreenLyrics = false;
  bool _vinylMode = false;
  bool _carMode = false;
  bool _showRemaining = false;
  bool _syncingMode = false;
  List<String> _syncLines = [];
  List<LyricLine> _recordedSync = [];
  String? _loadedSongId;
  int _lastActiveIdx = -1;
  Timer? _uiTick;
  final ScrollController _lyricScroll = ScrollController();
  late final AnimationController _spinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _uiTick = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      if (widget.getPlaying()) {
        if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
        if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
      } else {
        if (_spinCtrl.isAnimating) _spinCtrl.stop();
        if (_pulseCtrl.isAnimating) _pulseCtrl.stop();
      }
      final cur = widget.getSong();
      if (cur != null && cur.id != _loadedSongId) {
        _syncingMode = false;
        _fetchLyrics(cur);
      }
      final idx = _lyrics.lastIndexWhere((l) => l.at <= widget.getPos());
      if (idx != _lastActiveIdx && idx >= 0 && _lyricScroll.hasClients) {
        _lastActiveIdx = idx;
        final target = (idx * 42.0 - 70).clamp(0.0, _lyricScroll.position.maxScrollExtent);
        _lyricScroll.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
      setState(() {});
    });
    final cur = widget.getSong();
    if (cur != null) _fetchLyrics(cur);
  }

  String _stripJunk(String s) {
    final noParens = s.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\[[^\]]*\]'), '');
    return noParens.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<List<dynamic>> _queryLrclib(String q) async {
    final cleanQ = q.trim();
    if (cleanQ.isEmpty) return const [];
    final uri = Uri.parse('https://lrclib.net{Uri.encodeComponent(cleanQ)}');
    final res = await http.get(uri, headers: {'User-Agent': 'TypeShiApp/1.0'}).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    return const [];
  }

  void _applyLyricPayload(String synced, String plain) {
    final parsed = <LyricLine>[];
    final rx = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');
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
    if (mounted) {
      setState(() {
        _lyrics = parsed;
        _plainLyrics = (parsed.isEmpty && plain.isNotEmpty) ? plain : '';
      });
    }
  }

  Future<void> _fetchLyrics(Song song, {String? customQuery}) async {
    _loadedSongId = song.id;
    _lastActiveIdx = -1;
    setState(() {
      _loadingLyrics = true;
      _lyrics = [];
      _plainLyrics = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'lyrics_${song.id}';
    if (customQuery == null) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        _applyLyricPayload(data['synced'] ?? '', data['plain'] ?? '');
        if (mounted) setState(() => _loadingLyrics = false);
        return;
      }
    }

    try {
      final cleanTitle = _stripJunk(song.title);
      final cleanArtist = song.artist == 'Unknown Artist' ? '' : _stripJunk(song.artist);
      final cleanAlbum = _stripJunk(song.album);
      final queries = <String>[
        if (customQuery != null) customQuery,
        '$cleanTitle $cleanArtist'.trim(),
        if (cleanArtist.isNotEmpty) '$cleanArtist $cleanTitle'.trim(),
        if (cleanAlbum.isNotEmpty && cleanAlbum.toLowerCase() != cleanArtist.toLowerCase()) '$cleanTitle $cleanAlbum'.trim(),
        cleanTitle,
      ];
      List<dynamic> list = const [];
      for (final q in queries.toSet()) {
        list = await _queryLrclib(q);
        if (list.isNotEmpty) break;
      }
      if (list.isNotEmpty) {
        final best = list.firstWhere((e) => (e['syncedLyrics'] ?? '').toString().isNotEmpty, orElse: () => list.first);
        final synced = (best['syncedLyrics'] ?? '').toString();
        final plain = (best['plainLyrics'] ?? '').toString();
        await prefs.setString(cacheKey, jsonEncode({'synced': synced, 'plain': plain}));
        _applyLyricPayload(synced, plain);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLyrics = false);
  }

  Future<void> _manualLyricSearch(Song song) async {
    final c = TextEditingController(text: '${song.artist == 'Unknown Artist' ? '' : '${song.artist} '}${song.title}');
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        title: const Text('Search Lyrics'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Artist and song title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Search')),
        ],
      ),
    );
    if (q != null && q.isNotEmpty) await _fetchLyrics(song, customQuery: q);
  }

  void _startSyncMode() {
    final raw = _plainLyrics.isNotEmpty ? _plainLyrics : _lyrics.map((e) => e.text).join('\n');
    final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return;
    setState(() {
      _syncLines = lines;
      _recordedSync = [];
      _syncingMode = true;
    });
  }

  Future<void> _recordNextSyncLine(Song song) async {
    if (_recordedSync.length >= _syncLines.length) return;
    HapticFeedback.lightImpact();
    final idx = _recordedSync.length;
    _recordedSync.add(LyricLine(widget.getPos(), _syncLines[idx]));
    if (_recordedSync.length == _syncLines.length) {
      final lrc = _recordedSync.map((l) {
        final m = l.at.inMinutes.toString().padLeft(2, '0');
        final s = (l.at.inSeconds % 60).toString().padLeft(2, '0');
        final ms = ((l.at.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
        return '[$m:$s.$ms] ${l.text}';
      }).join('\n');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lyrics_${song.id}', jsonEncode({'synced': lrc, 'plain': _syncLines.join('\n')}));
      setState(() {
        _lyrics = List<LyricLine>.from(_recordedSync);
        _plainLyrics = '';
        _syncingMode = false;
      });
    } else {
      setState(() {});
    }
  }

  void _openQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121218),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = widget.getQueue();
          final curIdx = widget.getQueueIndex();
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Text('UP NEXT (${q.length})', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: widget.accent)),
                    const Spacer(),
                    const Text('Drag to reorder', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: q.length,
                  onReorder: (oldIndex, newIndex) {
                    widget.onReorderQueue(oldIndex, newIndex);
                    setSheetState(() {});
                  },
                  itemBuilder: (_, i) {
                    final item = q[i];
                    final isCurrent = i == curIdx;
                    return ListTile(
                      key: ValueKey('q_${item.id}_$i'),
                      leading: Icon(isCurrent ? Icons.equalizer_rounded : Icons.drag_handle_rounded, color: isCurrent ? widget.accent : Colors.white54),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: isCurrent ? widget.accent : Colors.white)),
                      subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onJumpToQueueIndex(i);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _uiTick?.cancel();
    _lyricScroll.dispose();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _buildLyricsCard(Song song, int activeIdx, {required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_syncingMode ? 'SYNC MODE' : 'LYRICS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: widget.accent)),
              const Spacer(),
              if (!_syncingMode && (_plainLyrics.isNotEmpty || _lyrics.isNotEmpty))
                IconButton(
                  icon: const Icon(Icons.timer_rounded, size: 20),
                  tooltip: 'Tap-to-Sync Lyrics',
                  onPressed: _startSyncMode,
                ),
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                tooltip: 'Paste Lyrics',
                onPressed: () async {
                  final clip = await Clipboard.getData('text/plain');
                  final txt = (clip?.text ?? '').trim();
                  if (txt.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('lyrics_${song.id}', jsonEncode({'synced': '', 'plain': txt}));
                    _syncingMode = false;
                    _applyLyricPayload('', txt);
                  }
                },
              ),
              IconButton(icon: const Icon(Icons.search_rounded, size: 20), onPressed: () => _manualLyricSearch(song)),
              IconButton(
                icon: Icon(_fullScreenLyrics ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 22),
                onPressed: () => setState(() => _fullScreenLyrics = !_fullScreenLyrics),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _syncingMode
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Line ${_recordedSync.length + 1} of ${_syncLines.length}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 10),
                      Text(
                        _recordedSync.length < _syncLines.length ? _syncLines[_recordedSync.length] : 'Done!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: widget.accent),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.black),
                        onPressed: () => _recordNextSyncLine(song),
                        icon: const Icon(Icons.touch_app_rounded),
                        label: const Text('Tap on Beat for Next Line', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  )
                : _loadingLyrics
                    ? Center(child: CircularProgressIndicator(color: widget.accent))
                    : _lyrics.isNotEmpty
                        ? ListView.builder(
                            controller: _lyricScroll,
                            itemCount: _lyrics.length,
                            itemBuilder: (_, i) {
                              final active = i == activeIdx;
                              return GestureDetector(
                                onTap: () => widget.player.seek(_lyrics[i].at),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active ? widget.accent.withValues(alpha: 0.14) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      fontSize: active ? 20 : 15,
                                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                                      color: active ? widget.accent : Colors.white54,
                                    ),
                                    child: Text(_lyrics[i].text),
                                  ),
                                ),
                              );
                            },
                          )
                        : _plainLyrics.isNotEmpty
                            ? SingleChildScrollView(child: Text(_plainLyrics, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)))
                            : const Center(child: Text('No lyrics found.\nTap search or paste lyrics from clipboard.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
          ),
        ],
      ),
    );
  }

  Widget _buildArtDisc(Song song, Color accent, bool hasArt) {
    final squareArt = Container(
      width: 232,
      height: 232,
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(28),
        image: hasArt ? DecorationImage(image: FileImage(File(song.artPath!)), fit: BoxFit.cover) : null,
      ),
      child: hasArt ? null : Icon(Icons.graphic_eq_rounded, size: 96, color: accent),
    );
    final vinylDisc = RotationTransition(
      turns: _spinCtrl,
      child: Container(
        width: 232,
        height: 232,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111116),
          border: Border.all(color: Colors.white12, width: 6),
        ),
        child: Center(
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E28),
              border: Border.all(color: accent, width: 3),
              image: hasArt ? DecorationImage(image: FileImage(File(song.artPath!)), fit: BoxFit.cover) : null,
            ),
            child: Center(child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle))),
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: () => setState(() => _vinylMode = !_vinylMode),
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -250) {
          HapticFeedback.lightImpact();
          widget.onNext();
        } else if (v > 250) {
          HapticFeedback.lightImpact();
          widget.onPrev();
        }
      },
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final glow = widget.getPlaying() ? (14.0 + 18.0 * _pulseCtrl.value) : 12.0;
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_vinylMode ? 140 : 32),
                  border: Border.all(color: accent.withValues(alpha: widget.getPlaying() ? 0.55 : 0.2), width: 2),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: glow, spreadRadius: 2)],
                ),
                child: child,
              );
            },
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _vinylMode ? vinylDisc : squareArt),
          ),
          const SizedBox(height: 8),
          Text(_vinylMode ? 'Swipe cover to skip • Tap for square' : 'Swipe cover to skip • Tap for Vinyl', style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.getSong();
    if (song == null) return const SizedBox.shrink();
    final accent = widget.accent;
    final pos = widget.getPos();
    final dur = widget.getDur();
    final playing = widget.getPlaying();
    final shuffle = widget.getShuffle();
    final loop = widget.getLoop();
    final speed = widget.getSpeed();
    final slowed = widget.getSlowedReverb();
    final sleepMins = widget.getSleepMinutes();
    final loopA = widget.getLoopA();
    final loopB = widget.getLoopB();
    final activeIdx = _lyrics.lastIndexWhere((l) => l.at <= pos);
    final hasArt = song.artPath != null && File(song.artPath!).existsSync();
    final remaining = dur > pos ? dur - pos : Duration.zero;

    return Scaffold(
      backgroundColor: const Color(0xFF08080C),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30), onPressed: () => Navigator.pop(context)),
        title: Text(_carMode ? 'CAR MODE' : 'NOW PLAYING', style: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.directions_car_rounded, color: _carMode ? accent : Colors.white),
            tooltip: 'Car Gesture Mode',
            onPressed: () => setState(() => _carMode = !_carMode),
          ),
          IconButton(icon: const Icon(Icons.equalizer_rounded), tooltip: '5-Band Equalizer', onPressed: widget.onOpenEq),
          IconButton(icon: const Icon(Icons.queue_music_rounded), onPressed: _openQueueSheet),
          PopupMenuButton<int?>(
            icon: Icon(Icons.bedtime_rounded, color: sleepMins != null ? Colors.amber : Colors.white),
            onSelected: widget.onSetSleep,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: null, child: Text('Sleep Timer: Off')),
              PopupMenuItem(value: 15, child: Text('15 minutes')),
              PopupMenuItem(value: 30, child: Text('30 minutes')),
              PopupMenuItem(value: 60, child: Text('60 minutes')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (hasArt)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                child: Opacity(opacity: 0.35, child: Image.file(File(song.artPath!), fit: BoxFit.cover)),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.1,
                  colors: [accent.withValues(alpha: 0.16), const Color(0xFF08080C).withValues(alpha: 0.88)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _carMode
                ? GestureDetector(
                    onTap: widget.onTogglePlay,
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200) widget.onNext();
                      if (v > 200) widget.onPrev();
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(song.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(song.artist, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white60)),
                          const SizedBox(height: 44),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 54), onPressed: widget.onPrev),
                              FloatingActionButton.large(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                onPressed: widget.onTogglePlay,
                                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 54),
                              ),
                              IconButton(icon: const Icon(Icons.skip_next_rounded, size: 54), onPressed: widget.onNext),
                            ],
                          ),
                          const SizedBox(height: 36),
                          const Text('Tap anywhere to Play/Pause • Swipe left/right to skip', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : _fullScreenLyrics
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Column(
                          children: [
                            Expanded(child: _buildLyricsCard(song, activeIdx, height: double.infinity)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 32), onPressed: widget.onPrev),
                                IconButton(icon: const Icon(Icons.replay_10_rounded, size: 28), onPressed: () => widget.onSeekBy(-10)),
                                FloatingActionButton(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.black,
                                  onPressed: widget.onTogglePlay,
                                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 34),
                                ),
                                IconButton(icon: const Icon(Icons.forward_10_rounded, size: 28), onPressed: () => widget.onSeekBy(10)),
                                IconButton(icon: const Icon(Icons.skip_next_rounded, size: 32), onPressed: widget.onNext),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          Center(child: _buildArtDisc(song, accent, hasArt)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(song.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 2),
                                    Text(song.artist, style: const TextStyle(fontSize: 15, color: Colors.white60)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(song.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: song.favorite ? accent : Colors.white54),
                                onPressed: widget.onToggleFavorite,
                              ),
                              InkWell(
                                onTap: widget.onToggleSlowedReverb,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: slowed ? accent.withValues(alpha: 0.22) : Colors.white10,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('Slow+Rev', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: slowed ? accent : Colors.white70)),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                                child: TextButton(
                                  onPressed: () {
                                    final next = speed == 1.0 ? 1.25 : (speed == 1.25 ? 1.5 : (speed == 1.5 ? 0.75 : 1.0));
                                    widget.onSetSpeed(next);
                                  },
                                  child: Text('${speed}x', style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Slider(
                            value: dur.inMilliseconds > 0 ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0,
                            max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                            onChanged: (v) => widget.player.seek(Duration(milliseconds: v.toInt())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => widget.onSetLoopA(pos),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: loopA != null ? accent.withValues(alpha: 0.22) : Colors.white10, borderRadius: BorderRadius.circular(8)),
                                      child: Text(loopA != null ? 'A ${_fmt(loopA)}' : 'Set A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: loopA != null ? accent : Colors.white60)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => widget.onSetLoopB(pos),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: loopB != null ? accent.withValues(alpha: 0.22) : Colors.white10, borderRadius: BorderRadius.circular(8)),
                                      child: Text(loopB != null ? 'B ${_fmt(loopB)}' : 'Set B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: loopB != null ? accent : Colors.white60)),
                                    ),
                                  ),
                                  if (loopA != null || loopB != null) ...[
                                    const SizedBox(width: 4),
                                    InkWell(onTap: widget.onClearAB, child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54)),
                                  ],
                                ],
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _showRemaining = !_showRemaining),
                                child: Text(_showRemaining ? '-${_fmt(remaining)}' : _fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(icon: Icon(Icons.shuffle_rounded, color: shuffle ? accent : Colors.white38, size: 22), onPressed: widget.onToggleShuffle),
                              IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 32), onPressed: widget.onPrev),
                              IconButton(icon: const Icon(Icons.replay_10_rounded, size: 28), onPressed: () => widget.onSeekBy(-10)),
                              FloatingActionButton.large(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                onPressed: widget.onTogglePlay,
                                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42),
                              ),
                              IconButton(icon: const Icon(Icons.forward_10_rounded, size: 28), onPressed: () => widget.onSeekBy(10)),
                              IconButton(icon: const Icon(Icons.skip_next_rounded, size: 32), onPressed: widget.onNext),
                              IconButton(
                                icon: Icon(loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: loop != LoopMode.off ? accent : Colors.white38, size: 22),
                                onPressed: widget.onCycleLoop,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _buildLyricsCard(song, activeIdx, height: 270),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

