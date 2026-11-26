import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(androidNotificationChannelId: 'com.typeshi.channel.audio', androidNotificationChannelName: 'Type Shi Playback', androidNotificationOngoing: true);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(const TypeShiApp());

const List<Color> kAccentPalette = [
  Color(0xFFFFFFFF),
  Color(0xFFFF2E55),
  Color(0xFFA855F7),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF06B6D4),
  Color(0xFF000000),
];

const List<String> kAccentNames = ['Pure Ice', 'Crimson', 'Purple', 'Emerald', 'Gold', 'Cyan', 'Full Black'];
const List<String> kFontNames = ['Modern Sans', 'Street Bold', 'Studio Mono'];
const List<String?> kFontFamilies = [null, 'sans-serif-condensed', 'monospace'];
const List<String> kMoodTags = ['Gym', 'Late Night', 'Chill', 'Hype'];
const List<String> kGlowNames = ['Subtle', 'Medium', 'Max Neon'];
const List<String> kParticleModes = ['Off', 'Embers', 'Snow', 'Sparkles', 'Neon Dust'];

const Map<String, List<double>> kEqPresets = {
  'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
  'Bass Boost': [6.5, 4.0, 0.0, 1.0, 2.5],
  'Hip-Hop': [5.5, 3.0, -1.0, 2.0, 4.5],
  'Vocal': [-1.5, 1.0, 4.5, 3.5, 1.0],
  'Midnight': [4.5, 2.0, -2.0, 1.5, 3.5],
  'AirPods Pro': [2.5, 1.0, 1.5, 2.0, 3.0],
  'Sony XM4/5': [-2.0, -1.0, 2.0, 3.0, 2.5],
  'Redmi Buds': [3.0, 1.5, 2.0, 1.0, 2.5],
  'Studio Flat': [0.5, 0.0, 0.0, 0.5, 1.0],
};

class VibePack {
  const VibePack(this.name, this.subtitle, this.accent, this.fontIndex, this.amoled, this.frosted, this.glowLevel);
  final String name;
  final String subtitle;
  final Color accent;
  final int fontIndex;
  final bool amoled;
  final bool frosted;
  final int glowLevel;

const List<VibePack> kVibePacks = [
  VibePack('Midnight Crimson', 'Pure black + Neon Red', Color(0xFFFF2E55), 0, true, false, 2),
  VibePack('Cyber Violet', 'Deep violet + Cyan', Color(0xFF06B6D4), 1, false, true, 2),
  VibePack('Studio Mono', 'Precision mono + Gold', Color(0xFFF59E0B), 2, true, false, 1),
  VibePack('Stealth Minimal', 'Matte charcoal + Ice', Color(0xFFFFFFFF), 0, false, true, 0),
];

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
    this.mood = '',
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
  final String mood;

  Song copyWith({String? title, String? artist, String? album, String? artPath, bool? favorite, int? playCount, int? durationMs, String? mood}) => Song(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        path: path,
        artPath: artPath ?? this.artPath,
        favorite: favorite ?? this.favorite,
        playCount: playCount ?? this.playCount,
        durationMs: durationMs ?? this.durationMs,
        mood: mood ?? this.mood,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'artist': artist, 'album': album, 'path': path, 'artPath': artPath, 'favorite': favorite, 'playCount': playCount, 'durationMs': durationMs, 'mood': mood};
  factory Song.fromJson(Map<String, dynamic> j) => Song(id: j['id'] ?? '', title: j['title'] ?? 'Unknown', artist: j['artist'] ?? 'Unknown Artist', album: j['album'] ?? '', path: j['path'] ?? '', artPath: j['artPath'], favorite: j['favorite'] ?? false, playCount: j['playCount'] ?? 0, durationMs: j['durationMs'] ?? 0, mood: j['mood'] ?? '');

class Playlist {
  Playlist({required this.id, required this.name, required this.songIds});
  final String id;
  String name;
  final List<String> songIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(id: j['id'] ?? '', name: j['name'] ?? 'Playlist', songIds: List<String>.from(j['songIds'] ?? const []));

class LyricLine {
  const LyricLine(this.at, this.text);
  final Duration at;
  final String text;

class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;
  @override
  State<MarqueeText> createState() => _MarqueeTextState();

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _sc = ScrollController();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_sc.hasClients || _sc.position.maxScrollExtent <= 0) return;
      final next = _sc.offset + 1.0;
      if (next >= _sc.position.maxScrollExtent) {
        _sc.jumpTo(0);
      } else {
        _sc.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _sc,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text('${widget.text}     ', style: widget.style),
    );
  }

class ProceduralNeonCover extends StatelessWidget {
  const ProceduralNeonCover({super.key, required this.seedText, required this.accent, required this.size, this.radius = 12});
  final String seedText;
  final Color accent;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hash = seedText.codeUnits.fold<int>(7, (a, b) => a * 31 + b);
    final hue = (hash % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.85, 0.52).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 55) % 360, 0.9, 0.42).toColor();
    final effective1 = accent == Colors.black ? const Color(0xFF22222A) : c1;
    final effective2 = accent == Colors.black ? const Color(0xFF0A0A0E) : c2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [effective1, effective2, Colors.black]),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5)),
          ),
          Icon(Icons.graphic_eq_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.44),
        ],
      ),
    );
  }

class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({super.key, required this.color, required this.playing, this.size = 20});
  final Color color;
  final bool playing;
  final double size;
  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);
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
        final vals = [0.35 + 0.65 * math.sin(t * math.pi).abs(), 0.35 + 0.65 * math.cos(t * math.pi * 0.85).abs(), 0.35 + 0.65 * math.sin((1 - t) * math.pi).abs()];
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: vals.map((f) => Container(width: widget.size * 0.2, height: widget.size * f, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(4)))).toList(),
          ),
        );
      },
    );
  }

class AmbientParticleOverlay extends StatefulWidget {
  const AmbientParticleOverlay({super.key, required this.mode, required this.accent});
  final String mode;
  final Color accent;
  @override
  State<AmbientParticleOverlay> createState() => _AmbientParticleOverlayState();

class _AmbientParticleOverlayState extends State<AmbientParticleOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  final List<Offset> _seeds = List.generate(26, (i) => Offset((i * 37 % 100) / 100.0, (i * 53 % 100) / 100.0));
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'Off') return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_seeds, _ctrl.value, widget.mode, widget.accent),
        ),
      ),
    );
  }

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.seeds, this.t, this.mode, this.accent);
  final List<Offset> seeds;
  final double t;
  final String mode;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final color = mode == 'Embers'
        ? const Color(0xFFFF5722)
        : mode == 'Snow'
            ? Colors.white
            : mode == 'Sparkles'
                ? const Color(0xFFFFD54F)
                : (accent == Colors.black ? Colors.white70 : accent);
    final paint = Paint()..color = color.withValues(alpha: 0.32);
    for (int i = 0; i < seeds.length; i++) {
      final s = seeds[i];
      final falling = mode == 'Snow';
      final dy = falling ? ((s.dy + t * (0.6 + (i % 3) * 0.2)) % 1.0) : ((1.0 + s.dy - t * (0.5 + (i % 3) * 0.2)) % 1.0);
      final dx = (s.dx + math.sin((t * 2 * math.pi) + i) * 0.03) % 1.0;
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), 1.8 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;

class MatrixVisualizerBar extends StatefulWidget {
  const MatrixVisualizerBar({super.key, required this.accent, required this.playing});
  final Color accent;
  final bool playing;
  @override
  State<MatrixVisualizerBar> createState() => _MatrixVisualizerBarState();

class _MatrixVisualizerBarState extends State<MatrixVisualizerBar> {
  final _rng = math.Random();
  Timer? _t;
  List<String> _cols = List.filled(24, '0');
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() {
        _cols = List.generate(24, (_) => widget.playing ? ['0', '1', '█', '▓', '▒', '░', '#'][_rng.nextInt(7)] : '·');
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accent == Colors.black ? Colors.white : widget.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.35))),
      child: Text(_cols.join(' '), maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w900, color: c)),
    );
  }

class CircularSleepDial extends StatefulWidget {
  const CircularSleepDial({super.key, required this.accent, required this.initialMinutes});
  final Color accent;
  final int initialMinutes;
  @override
  State<CircularSleepDial> createState() => _CircularSleepDialState();

class _CircularSleepDialState extends State<CircularSleepDial> {
  late int _mins = widget.initialMinutes.clamp(1, 45);
  void _updateFromOffset(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = (math.atan2(local.dy - center.dy, local.dx - center.dx) + math.pi / 2 + 2 * math.pi) % (2 * math.pi);
    setState(() => _mins = ((angle / (2 * math.pi)) * 45).round().clamp(1, 45));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accent == Colors.black ? Colors.white : widget.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanDown: (d) => _updateFromOffset(d.localPosition, const Size(190, 190)),
          onPanUpdate: (d) => _updateFromOffset(d.localPosition, const Size(190, 190)),
          child: SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 165,
                  height: 165,
                  child: CircularProgressIndicator(value: _mins / 45.0, strokeWidth: 12, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(c)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_mins}m', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: c)),
                    const Text('15s Fade-Out', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('Turn Off')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.black), onPressed: () => Navigator.pop(context, _mins), child: Text('Set ${_mins}m')),
          ],
        ),
      ],
    );
  }

class TypeShiApp extends StatefulWidget {
  const TypeShiApp({super.key});
  @override
  State<TypeShiApp> createState() => _TypeShiAppState();

class _TypeShiAppState extends State<TypeShiApp> {
  int _accentIndex = 0;
  Color? _customAccent;
  int _fontIndex = 0;
  bool _amoledBlack = true;
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
    final customVal = prefs.getInt('customAccentVal');
    final amoled = prefs.getBool('amoledBlack') ?? true;
    if (mounted) {
      setState(() {
        if (idx >= 0 && idx < kAccentPalette.length) _accentIndex = idx;
        if (fIdx >= 0 && fIdx < kFontNames.length) _fontIndex = fIdx;
        if (customVal != null) _customAccent = Color(customVal);
        _amoledBlack = amoled;
      });
    }
  }

  Future<void> _setAccent(int idx) async {
    setState(() {
      _accentIndex = idx;
      _customAccent = null;
      _dynamicAccent = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentIndex', idx);
    await prefs.remove('customAccentVal');
  }

  Future<void> _setCustomColor(Color c) async {
    setState(() {
      _customAccent = c;
      _dynamicAccent = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('customAccentVal', c.toARGB32());
  }

  Future<void> _setFont(int idx) async {
    setState(() => _fontIndex = idx);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontIndex', idx);
  }

  Future<void> _setAmoled(bool v) async {
    setState(() => _amoledBlack = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('amoledBlack', v);
  }

  @override
  Widget build(BuildContext context) {
    final rawAccent = _dynamicAccent ?? _customAccent ?? kAccentPalette[_accentIndex];
    final isFullBlack = rawAccent == const Color(0xFF000000);
    final uiAccent = isFullBlack ? Colors.white : rawAccent;
    final family = kFontFamilies[_fontIndex];
    final bg = _amoledBlack ? Colors.black : const Color(0xFF0D0D12);

    return MaterialApp(
      title: 'Type Shi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: family),
        colorScheme: ColorScheme.dark(primary: uiAccent, onPrimary: Colors.black, surface: const Color(0xFF0E0E13)),
        sliderTheme: SliderThemeData(activeTrackColor: uiAccent, inactiveTrackColor: Colors.white12, thumbColor: uiAccent, trackHeight: 3.5),
      ),
      home: HomeScreen(
        rawAccent: rawAccent,
        accent: uiAccent,
        isFullBlackAccent: isFullBlack,
        accentIndex: _accentIndex,
        fontIndex: _fontIndex,
        amoledBlack: _amoledBlack,
        onSelectAccent: _setAccent,
        onSelectCustomAccent: _setCustomColor,
        onSelectFont: _setFont,
        onToggleAmoled: _setAmoled,
        onDynamicAccent: (c) => setState(() => _dynamicAccent = c),
      ),
    );
  }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.rawAccent,
    required this.accent,
    required this.isFullBlackAccent,
    required this.accentIndex,
    required this.fontIndex,
    required this.amoledBlack,
    required this.onSelectAccent,
    required this.onSelectCustomAccent,
    required this.onSelectFont,
    required this.onToggleAmoled,
    required this.onDynamicAccent,
  });

  final Color rawAccent;
  final Color accent;
  final bool isFullBlackAccent;
  final int accentIndex;
  final int fontIndex;
  final bool amoledBlack;
  final Future<void> Function(int) onSelectAccent;
  final Future<void> Function(Color) onSelectCustomAccent;
  final Future<void> Function(int) onSelectFont;
  final Future<void> Function(bool) onToggleAmoled;
  final void Function(Color?) onDynamicAccent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();

class _HomeScreenState extends State<HomeScreen> {
  static const EventChannel _noisyChannel = EventChannel('typeshi/noisy');
  static const EventChannel _sensorChannel = EventChannel('typeshi/sensors');
  static const MethodChannel _sysChannel = MethodChannel('typeshi/system');

  final AndroidEqualizer _eq = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_eq]));
  final AudioPlayer _ambientPlayer = AudioPlayer();

  final List<Song> _songs = [];
  final List<Playlist> _playlists = [];
  final Set<String> _selectedIds = {};
  List<Song> _queue = [];
  int _index = -1;
  int _tab = 0;
  int _filterTab = 0;
  int _browseMode = 0;
  String _selectedMood = '';
  bool _enableBrowseTabs = false;
  bool _dynamicCoverColor = true;
  bool _showMiniLyric = true;
  bool _autoPauseNoisy = true;
  bool _shakeToSkip = false;
  bool _gyroTilt = true;
  bool _volumeNormalizer = false;
  bool _frostedGlass = false;
  bool _beatReactive = true;
  bool _matrixVisualizer = false;
  bool _batterySaver = false;
  int _batteryLevel = 100;
  String _particleMode = 'Off';
  String _ambientOverlay = 'Off'; // Off, Rain, Vinyl
  bool _vocalMute = false;
  bool _spatial8D = false;
  bool _lofiMode = false;
  int _glowLevel = 1;
  bool _slowedReverb = false;
  bool _sortAZ = false;
  int _crossfadeSec = 0;
  int _totalSecondsListened = 0;
  String _eqPreset = 'Flat';
  List<double> _eqGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  String _query = '';
  String _bannerTitle = 'Type Shi';
  String? _bgPath;
  bool _playing = false;
  bool _shuffle = false;
  LoopMode _loop = LoopMode.off;
  double _speed = 1.0;
  double _pitch = 1.0;
  double _gyroX = 0.0;
  double _gyroY = 0.0;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  Duration? _loopA;
  Duration? _loopB;
  Timer? _sleepTimer;
  Timer? _sleepFadeTimer;
  Timer? _statTimer;
  Timer? _spatialTimer;
  StreamSubscription? _noisySub;
  StreamSubscription? _sensorSub;
  int? _sleepMinutes;
  bool _crossfading = false;
  bool _handlingComplete = false;
  List<LyricLine> _miniLyrics = [];
  String? _miniLyricsSongId;

  Song? get _current => (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get _selecting => _selectedIds.isNotEmpty;
  double get _glowScale => _batterySaver ? 0.2 : (_glowLevel == 0 ? 0.35 : (_glowLevel == 2 ? 2.1 : 1.0));

  @override
  void initState() {
    super.initState();
    _initStorageAndStreams();
  }

    Future<void> _checkBattery() async {
    try { final lvl = await _sysChannel.invokeMethod<int>('getBatteryLevel'); if (lvl != null && lvl > 0 && mounted) setState(() { _batteryLevel = lvl; if (lvl < 20) _batterySaver = true; }); } catch (_) {}
  }

  Future<void> _initStorageAndStreams() async {
    _checkBattery();
    _noisySub = _noisyChannel.receiveBroadcastStream().listen((_) { if (_autoPauseNoisy && _playing) _player.pause(); });
    _sensorSub = _sensorChannel.receiveBroadcastStream().listen((ev) {
      if (ev is Map && ev['type'] == 'shake' && _shakeToSkip && _songs.isNotEmpty) { HapticFeedback.mediumImpact(); if (_queue.isEmpty) { _playFromQueue(_songs, 0, shuffleStart: true); } else { final ps = _shuffle; _shuffle = true; _next().then((_) => _shuffle = ps); } }
      else if (ev is Map && ev['type'] == 'gyro' && _gyroTilt && !_batterySaver && mounted) { setState(() { _gyroX = (_gyroX * 0.85 + ((ev['y'] as num?)?.toDouble() ?? 0.0) * 0.04).clamp(-0.22, 0.22); _gyroY = (_gyroY * 0.85 + ((ev['x'] as num?)?.toDouble() ?? 0.0) * 0.04).clamp(-0.22, 0.22); }); }
    });
    double panPhase = 0.0;
    _spatialTimer = Timer.periodic(const Duration(milliseconds: 120), (_) { if (_spatial8D && _playing) { panPhase += 0.14; _player.setVolume((_volumeNormalizer ? 0.85 : 1.0) * (0.82 + 0.18 * math.sin(panPhase))); } });
    _statTimer = Timer.periodic(const Duration(seconds: 5), (_) { _checkBattery(); if (_playing) { _totalSecondsListened += 5; SharedPreferences.getInstance().then((p) { p.setInt('totalSec', _totalSecondsListened); if (_current != null) { p.setString('lastSongId', _current!.id); p.setInt('lastPosMs', _pos.inMilliseconds); } }); } });
    _player.positionStream.listen((p) { if (!mounted) return; setState(() => _pos = p); if (_loopA != null && _loopB != null && _loopB! > _loopA! && p >= _loopB!) _player.seek(_loopA!); if (_crossfadeSec > 0 && !_crossfading && _dur.inSeconds > _crossfadeSec + 2 && (_dur - p).inMilliseconds <= _crossfadeSec * 1000 && (_dur - p).inMilliseconds > 200) _triggerCrossfade(); });
    _player.durationStream.listen((d) { if (!mounted || d == null) return; setState(() => _dur = d); if (_current != null && _current!.durationMs == 0 && d.inMilliseconds > 0) { final u = _current!.copyWith(durationMs: d.inMilliseconds); _queue[_index] = u; final i = _songs.indexWhere((e) => e.id == u.id); if (i >= 0) _songs[i] = u; _saveData(); } });
    _player.playerStateStream.listen((st) { if (!mounted) return; setState(() => _playing = st.playing); if (st.playing && _ambientOverlay != 'Off') { _ambientPlayer.play(); } else if (!st.playing) { _ambientPlayer.pause(); } if (st.processingState == ProcessingState.completed && _loop != LoopMode.one && !_crossfading && !_handlingComplete) { _handlingComplete = true; _next().whenComplete(() => _handlingComplete = false); } });
    final prefs = await SharedPreferences.getInstance();
    final rawSongs = prefs.getString('songs'); if (rawSongs != null && rawSongs.isNotEmpty) _songs.addAll((jsonDecode(rawSongs) as List).map((e) => Song.fromJson(Map<String, dynamic>.from(e))));
    final rawPl = prefs.getString('playlists'); if (rawPl != null && rawPl.isNotEmpty) _playlists.addAll((jsonDecode(rawPl) as List).map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))));
    final bg = prefs.getString('bgPath'); if (bg != null && File(bg).existsSync()) _bgPath = bg;
    final savedBanner = prefs.getString('bannerTitle'); if (savedBanner != null && savedBanner.isNotEmpty) _bannerTitle = savedBanner;
    _enableBrowseTabs = prefs.getBool('enableBrowseTabs') ?? false; _dynamicCoverColor = prefs.getBool('dynamicCoverColor') ?? true; _showMiniLyric = prefs.getBool('showMiniLyric') ?? true; _autoPauseNoisy = prefs.getBool('autoPauseNoisy') ?? true; _shakeToSkip = prefs.getBool('shakeToSkip') ?? false; _gyroTilt = prefs.getBool('gyroTilt') ?? true; _volumeNormalizer = prefs.getBool('volumeNormalizer') ?? false; _frostedGlass = prefs.getBool('frostedGlass') ?? false; _beatReactive = prefs.getBool('beatReactive') ?? true; _matrixVisualizer = prefs.getBool('matrixVisualizer') ?? false; _particleMode = prefs.getString('particleMode') ?? 'Off'; _glowLevel = prefs.getInt('glowLevel') ?? 1; _crossfadeSec = prefs.getInt('crossfadeSec') ?? 0; _totalSecondsListened = prefs.getInt('totalSec') ?? 0; _eqPreset = prefs.getString('eqPreset') ?? 'Flat';
    final rawGains = prefs.getString('eqGains'); if (rawGains != null) _eqGains = (jsonDecode(rawGains) as List).map((e) => (e as num).toDouble()).toList();
    await _applyEq();
    final lastId = prefs.getString('lastSongId'); final lastPosMs = prefs.getInt('lastPosMs') ?? 0;
    if (lastId != null && _songs.isNotEmpty) {
      final f = _songs.indexWhere((s) => s.id == lastId);
      if (f >= 0) {
        _queue = List<Song>.from(_songs);
        _index = f;
        _pos = Duration(milliseconds: lastPosMs);
        if (mounted) setState(() {});
        Future.microtask(() async {
          await _extractCoverColor(_songs[f]);
          await _loadMiniLyrics(_songs[f]);
                            final curSong = _songs[f];
          await _player.setAudioSource(AudioSource.file(curSong.path, tag: MediaItem(id: curSong.id, title: curSong.title, artist: curSong.artist, album: curSong.album.isEmpty ? 'Type Shi' : curSong.album, artUri: curSong.artPath != null ? Uri.file(curSong.artPath!) : null)));
          if (lastPosMs > 0) await _player.seek(Duration(milliseconds: lastPosMs));
        });
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _setAmbientOverlay(String mode) async {
    setState(() => _ambientOverlay = mode);
    await _ambientPlayer.stop();
    if (mode == 'Off') return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ambient_${mode.toLowerCase()}.wav');
    if (!file.existsSync()) {
      const sampleRate = 16000;
      const seconds = 4;
      const numSamples = sampleRate * seconds;
      final bytes = BytesBuilder();
      final rng = math.Random(42);
      void writeStr(String s) => bytes.add(ascii.encode(s));
      void write32(int v) => bytes.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
      void write16(int v) => bytes.add([v & 0xff, (v >> 8) & 0xff]);
      writeStr('RIFF');
      write32(36 + numSamples * 2);
      writeStr('WAVEfmt ');
      write32(16);
      write16(1);
      write16(1);
      write32(sampleRate);
      write32(sampleRate * 2);
      write16(2);
      write16(16);
      writeStr('data');
      write32(numSamples * 2);
      double lowPass = 0.0;
      for (int i = 0; i < numSamples; i++) {
        final white = rng.nextDouble() * 2.0 - 1.0;
        lowPass = lowPass * 0.92 + white * 0.08;
        double sample = mode == 'Rain' ? (lowPass * 2200) : ((rng.nextDouble() < 0.004 ? (rng.nextDouble() * 2 - 1) * 5500 : lowPass * 450));
        write16(sample.round().clamp(-32767, 32767));
      }
      await file.writeAsBytes(bytes.toBytes(), flush: true);
    }
    await _ambientPlayer.setFilePath(file.path);
    await _ambientPlayer.setLoopMode(LoopMode.one);
    await _ambientPlayer.setVolume(0.35);
    if (_playing) await _ambientPlayer.play();
  }

  Future<void> _applyEq() async {
    try {
      final params = await _eq.parameters;
      final bands = params.bands;
      final effective = List<double>.from(_eqGains);
      if (_vocalMute) {
        effective[1] = -8.0;
        effective[2] = -10.0;
        effective[3] = -8.0;
        effective[0] = (effective[0] + 4.0).clamp(-10.0, 10.0);
      }
      if (_lofiMode) {
        effective[0] = 3.5;
        effective[3] = -6.0;
        effective[4] = -9.0;
      }
      for (int i = 0; i < bands.length && i < effective.length; i++) {
        await bands[i].setGain(effective[i]);
      }
      await _eq.setEnabled(_eqPreset != 'Flat' || _vocalMute || _lofiMode);
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
    await prefs.setBool('autoPauseNoisy', _autoPauseNoisy);
    await prefs.setBool('shakeToSkip', _shakeToSkip);
    await prefs.setBool('gyroTilt', _gyroTilt);
    await prefs.setBool('volumeNormalizer', _volumeNormalizer);
    await prefs.setBool('frostedGlass', _frostedGlass);
    await prefs.setBool('beatReactive', _beatReactive);
    await prefs.setBool('matrixVisualizer', _matrixVisualizer);
    await prefs.setString('particleMode', _particleMode);
    await prefs.setInt('glowLevel', _glowLevel);
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
    return noParens.replaceAll(RegExp(r'\.(mp3|m4a|wav|flac|ogg|aac)$', caseSensitive: false), '').replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
      String title = '', artist = '', album = '';
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
      if (title.isEmpty) title = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : cleanName;
      if (artist.isEmpty) artist = parts.length > 1 ? parts.first.trim() : (album.isNotEmpty ? album : 'Unknown Artist');
      _songs.add(Song(id: 's_$stamp', title: title, artist: artist, album: album, path: dest, artPath: embeddedArt));
      added++;
    }
    await _saveData();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $added track(s)')));
  }

  Future<void> _importSongs() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    await _importFileList(files.where((f) => f.path != null).map((f) => File(f.path!)).toList());
  }

  Future<void> _importFolder() async {
    final folderPath = await FilePicker.getDirectoryPath();
    if (folderPath == null) return;
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return;
    final exts = {'.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac'};
    await _importFileList(dir.listSync(recursive: true).whereType<File>().where((f) => exts.any(f.path.toLowerCase().endsWith)).toList());
  }

  Future<void> _swapArtistAndTitle(Song s) async {
    HapticFeedback.mediumImpact();
    final updated = s.copyWith(title: s.artist, artist: s.title);
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Swapped: "${updated.title}" — ${updated.artist}')));
    }
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

  Future<void> _setSongMood(Song s) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF16161C),
        title: const Text('Select Vibe / Mood Tag'),
        children: [
          ...kMoodTags.map((m) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(m, style: TextStyle(fontWeight: FontWeight.w800, color: s.mood == m ? widget.accent : Colors.white))))),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ''), child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Clear Tag', style: TextStyle(color: Colors.white54)))),
        ],
      ),
    );
    if (picked == null) return;
    final updated = s.copyWith(mood: picked);
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
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
        final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2);
        if (r + g + b > 90 && r + g + b < 680) { rSum += r; gSum += g; bSum += b; count++; }
      }
      if (count > 0) {
        final hsl = HSLColor.fromColor(Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count));
        widget.onDynamicAccent(hsl.withSaturation((hsl.saturation + 0.25).clamp(0.45, 0.95)).withLightness(0.62).toColor());
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
      final synced = ((jsonDecode(cached) as Map<String, dynamic>)['synced'] ?? '').toString();
      final rx = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');
      final parsed = <LyricLine>[];
      for (final line in synced.split('\n')) {
        final m = rx.firstMatch(line);
        if (m != null) {
          final txt = m.group(4)!.trim();
          if (txt.isNotEmpty) parsed.add(LyricLine(Duration(minutes: int.parse(m.group(1)!), seconds: int.parse(m.group(2)!), milliseconds: int.parse(m.group(3)!.padRight(3, '0').substring(0, 3))), txt));
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
    if (_queue.isEmpty) { _playFromQueue([s], 0); return; }
    setState(() => _queue.insert((_index + 1).clamp(0, _queue.length), s));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing "${s.title}" next'), duration: const Duration(seconds: 2)));
  }

  Future<void> _triggerCrossfade() async {
    if (_queue.length <= 1) return;
    _crossfading = true;
    final targetVol = _volumeNormalizer ? 0.85 : 1.0;
    try {
      for (int i = 4; i >= 1; i--) { await _player.setVolume(targetVol * (i / 5.0)); await Future.delayed(Duration(milliseconds: (_crossfadeSec * 150).clamp(150, 600))); }
      await _next();
      for (int i = 1; i <= 5; i++) { await _player.setVolume(targetVol * (i / 5.0)); await Future.delayed(Duration(milliseconds: (_crossfadeSec * 150).clamp(150, 600))); }
    } finally {
      await _player.setVolume(targetVol);
      _crossfading = false;
    }
  }

  Future<void> _playFromQueue(List<Song> queue, int startIndex, {bool shuffleStart = false}) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) return;
    final list = List<Song>.from(queue);
    if (shuffleStart && list.length > 1) { list.shuffle(); _shuffle = true; }
    final target = list[startIndex];
    final bumped = target.copyWith(playCount: target.playCount + 1);
    list[startIndex] = bumped;
    final mainIdx = _songs.indexWhere((e) => e.id == target.id);
    if (mainIdx >= 0) _songs[mainIdx] = bumped;

    setState(() { _queue = list; _index = startIndex; _pos = Duration.zero; _dur = Duration.zero; _loopA = null; _loopB = null; });
    await _saveData();
    await _extractCoverColor(bumped);
    await _loadMiniLyrics(bumped);
    await _player.setVolume(_volumeNormalizer ? 0.85 : 1.0);
    final curSong = _queue[_index];
    await _player.setAudioSource(AudioSource.file(curSong.path, tag: MediaItem(id: curSong.id, title: curSong.title, artist: curSong.artist, album: curSong.album.isEmpty ? 'Type Shi' : curSong.album, artUri: curSong.artPath != null ? Uri.file(curSong.artPath!) : null)));
    await _player.setSpeed(_slowedReverb ? 0.85 : (_lofiMode ? 0.92 : _speed));
    await _player.setPitch(_slowedReverb ? 0.88 : (_lofiMode ? 0.94 : _pitch));
    await _player.play();
  }

  Future<void> _next() async {
    if (_queue.isEmpty) return;
    if (_shuffle && _queue.length > 1) {
      final c = List.generate(_queue.length, (i) => i)..remove(_index)..shuffle();
      await _playFromQueue(_queue, c.first);
      return;
    }
    if (_index + 1 < _queue.length) { await _playFromQueue(_queue, _index + 1); }
    else if (_loop == LoopMode.all) { await _playFromQueue(_queue, 0); }
  }

  Future<void> _prev() async {
    if (_queue.isEmpty) return;
    if (_pos.inSeconds > 3) { await _player.seek(Duration.zero); return; }
    if (_index - 1 >= 0) { await _playFromQueue(_queue, _index - 1); }
    else if (_loop == LoopMode.all) { await _playFromQueue(_queue, _queue.length - 1); }
  }

  Future<void> _seekBy(int seconds) async {
    if (_dur.inMilliseconds <= 0) return;
    await _player.seek(Duration(milliseconds: (_pos.inMilliseconds + seconds * 1000).clamp(0, _dur.inMilliseconds)));
  }

  void _startFadeOutSleepTimer(int? mins) {
    _sleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    setState(() => _sleepMinutes = mins);
    if (mins == null || mins <= 0) {
      setState(() => _sleepMinutes = null);
      _player.setVolume(_volumeNormalizer ? 0.85 : 1.0);
      return;
    }
    _sleepFadeTimer = Timer(Duration(seconds: (mins * 60 - 15).clamp(1, 36000)), () {
      int step = 15;
      final startVol = _volumeNormalizer ? 0.85 : 1.0;
      Timer.periodic(const Duration(seconds: 1), (t) {
        step--;
        if (step <= 0 || _sleepMinutes == null) { t.cancel(); } else { _player.setVolume(startVol * (step / 15.0)); }
      });
    });
    _sleepTimer = Timer(Duration(minutes: mins), () async {
      await _player.pause();
      await _player.setVolume(_volumeNormalizer ? 0.85 : 1.0);
      if (mounted) setState(() => _sleepMinutes = null);
    });
  }

  Future<String?> _promptText(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF16161C), title: Text(title), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Enter name')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save'))]));
  }

  Future<void> _editTrackDialog(Song s) async {
    final titleCtrl = TextEditingController(text: s.title);
    final artistCtrl = TextEditingController(text: s.artist == 'Unknown Artist' ? '' : s.artist);
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF16161C), title: const Text('Edit Track Info'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Song Title')), const SizedBox(height: 12), TextField(controller: artistCtrl, decoration: const InputDecoration(labelText: 'Artist Name'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))]));
    if (saved != true || titleCtrl.text.trim().isEmpty) return;
    final updated = s.copyWith(title: titleCtrl.text.trim(), artist: artistCtrl.text.trim().isEmpty ? 'Unknown Artist' : artistCtrl.text.trim());
    final idx = _songs.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _songs[idx] = updated;
    final qIdx = _queue.indexWhere((e) => e.id == s.id);
    if (qIdx >= 0) _queue[qIdx] = updated;
    await _saveData();
    if (mounted) setState(() {});
  }

  Future<void> _batchFavorite() async {
    for (int i = 0; i < _songs.length; i++) { if (_selectedIds.contains(_songs[i].id)) _songs[i] = _songs[i].copyWith(favorite: true); }
    setState(() => _selectedIds.clear());
    await _saveData();
  }

  Future<void> _batchAddToPlaylist() async {
    final name = await _promptText('Playlist name');
    if (name == null || name.isEmpty) return;
    final existing = _playlists.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
    final target = existing.isNotEmpty ? existing.first : Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: []);
    if (existing.isEmpty) _playlists.add(target);
    for (final id in _selectedIds) { if (!target.songIds.contains(id)) target.songIds.add(id); }
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
    if (dupIds.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No duplicate tracks found!'))); return; }
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
      for (final k in prefs.getKeys()) { if (k.startsWith('lyrics_')) { final v = prefs.getString(k); if (v != null) lyricMap[k] = v; } }
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 14),
              Row(children: [Text('AUTO-EQ & 5-BAND DSP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: widget.accent)), const Spacer(), Text(_eqPreset, style: const TextStyle(fontSize: 12, color: Colors.white60))]),
              const SizedBox(height: 12),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: kEqPresets.keys.map((name) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(name), selected: _eqPreset == name, onSelected: (_) async { _eqPreset = name; _eqGains = List<double>.from(kEqPresets[name]!); await _applyEq(); setState(() {}); setSheetState(() {}); }))).toList())),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (i) => Column(children: [
                Text('${_eqGains[i].toStringAsFixed(1)}dB', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                SizedBox(height: 125, child: RotatedBox(quarterTurns: 3, child: Slider(min: -10, max: 10, value: _eqGains[i].clamp(-10.0, 10.0), onChanged: (v) async { _eqPreset = 'Custom'; _eqGains[i] = v; await _applyEq(); setState(() {}); setSheetState(() {}); }))),
                Text(bands[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ]))),
            ]),
          );
        },
      ),
    );
  }

  void _openMonthlyReceiptSheet() {
    final top = _songs.where((s) => s.playCount > 0).toList()..sort((a, b) => b.playCount.compareTo(a.playCount));
    final totalPlays = _songs.fold<int>(0, (sum, s) => sum + s.playCount);
    final mins = (_totalSecondsListened / 60).round();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: const Color(0xFFF6F4EE), borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24)]),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_bannerTitle.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 2)),
            Text('MONTHLY LISTENING RECEIPT • $dateStr', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54)),
            const Divider(color: Colors.black45, thickness: 1, height: 22),
            if (top.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('NO TRACKS PLAYED YET', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black87)))
            else ...top.take(8).toList().asMap().entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              Text('0${e.key + 1} ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Colors.black54, fontSize: 12)),
              Expanded(child: Text('${e.value.title} - ${e.value.artist}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Colors.black, fontSize: 12))),
              Text(' x${e.value.playCount}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Colors.black, fontSize: 12)),
            ]))),
            const Divider(color: Colors.black45, thickness: 1, height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL PLAYS:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Colors.black)), Text('$totalPlays', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Colors.black))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('MINUTES LISTENED:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Colors.black)), Text('$mins MIN', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Colors.black))]),
            const SizedBox(height: 14),
            const Text('|||| ||| || |||| ||| || |||| |||', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2, color: Colors.black87)),
            const Text('MADE BY AAKAS', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx), child: const Text('Close Receipt')),
          ]),
        ),
      ),
    );
  }

  void _openNowPlaying() {
    if (_current == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NowPlayingSheet(
        rawAccent: widget.rawAccent, accent: widget.accent, isFullBlackAccent: widget.isFullBlackAccent, glowScale: _glowScale,
        gyroX: () => _gyroX, gyroY: () => _gyroY, beatReactive: _beatReactive, matrixVisualizer: _matrixVisualizer, particleMode: _particleMode, batterySaver: _batterySaver,
        getSong: () => _current, getQueue: () => _queue, getQueueIndex: () => _index, getPlaying: () => _playing, getPos: () => _pos, getDur: () => _dur,
        getShuffle: () => _shuffle, getLoop: () => _loop, getSpeed: () => _speed, getPitch: () => _pitch, getSlowedReverb: () => _slowedReverb,
        getVocalMute: () => _vocalMute, getSpatial8D: () => _spatial8D, getLofiMode: () => _lofiMode, getAmbientOverlay: () => _ambientOverlay,
        getSleepMinutes: () => _sleepMinutes, getLoopA: () => _loopA, getLoopB: () => _loopB, player: _player,
        onTogglePlay: () => _playing ? _player.pause() : _player.play(),
        onToggleFavorite: () { if (_current != null) _toggleFavorite(_current!); },
        onNext: _next, onPrev: _prev, onSeekBy: _seekBy,
        onToggleSlowedReverb: () async { _slowedReverb = !_slowedReverb; await _player.setSpeed(_slowedReverb ? 0.85 : _speed); await _player.setPitch(_slowedReverb ? 0.88 : _pitch); _eqPreset = _slowedReverb ? 'Midnight' : 'Flat'; _eqGains = List<double>.from(kEqPresets[_eqPreset]!); await _applyEq(); setState(() {}); },
        onToggleVocalMute: () async { _vocalMute = !_vocalMute; await _applyEq(); setState(() {}); },
        onToggleSpatial8D: () async { _spatial8D = !_spatial8D; if (!_spatial8D) await _player.setVolume(_volumeNormalizer ? 0.85 : 1.0); setState(() {}); },
        onToggleLofi: () async { _lofiMode = !_lofiMode; await _player.setSpeed(_lofiMode ? 0.92 : _speed); await _player.setPitch(_lofiMode ? 0.94 : _pitch); await _setAmbientOverlay(_lofiMode ? 'Vinyl' : 'Off'); await _applyEq(); setState(() {}); },
        onCycleAmbient: () async { await _setAmbientOverlay(_ambientOverlay == 'Off' ? 'Rain' : (_ambientOverlay == 'Rain' ? 'Vinyl' : 'Off')); },
        onOpenEq: _openEqSheet, onSetLoopA: (d) => setState(() => _loopA = d), onSetLoopB: (d) => setState(() => _loopB = d), onClearAB: () => setState(() { _loopA = null; _loopB = null; }),
        onJumpToQueueIndex: (idx) => _playFromQueue(_queue, idx),
        onReorderQueue: (oldIdx, newIdx) { setState(() { if (newIdx > oldIdx) newIdx -= 1; final item = _queue.removeAt(oldIdx); _queue.insert(newIdx, item); if (_index == oldIdx) { _index = newIdx; } else if (oldIdx < _index && newIdx >= _index) { _index -= 1; } else if (oldIdx > _index && newIdx <= _index) { _index += 1; } }); },
        onToggleShuffle: () => setState(() => _shuffle = !_shuffle),
        onCycleLoop: () async { final next = _loop == LoopMode.off ? LoopMode.all : (_loop == LoopMode.all ? LoopMode.one : LoopMode.off); await _player.setLoopMode(next); setState(() => _loop = next); },
        onSetSpeed: (s) async { await _player.setSpeed(s); setState(() { _speed = s; _slowedReverb = false; _lofiMode = false; }); },
        onSetPitch: (p) async { await _player.setPitch(p); setState(() { _pitch = p; _slowedReverb = false; _lofiMode = false; }); },
        onSetSleep: _startFadeOutSleepTimer,
      ),
    ));
  }

  Widget _buildArtBox(Song s, {double size = 48, double radius = 12, bool active = false}) {
    final hasArt = s.artPath != null && File(s.artPath!).existsSync();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), border: Border.all(color: active ? widget.accent.withValues(alpha: (0.65 * _glowScale).clamp(0.15, 1.0)) : Colors.white10), image: hasArt ? DecorationImage(image: FileImage(File(s.artPath!)), fit: BoxFit.cover) : null),
      child: Stack(alignment: Alignment.center, children: [
        if (!hasArt) ProceduralNeonCover(seedText: '${s.title}${s.artist}', accent: widget.rawAccent, size: size, radius: radius),
        if (active) Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(radius)), child: Center(child: AnimatedEqualizer(color: widget.accent, playing: _playing, size: size * 0.44))),
      ]),
    );
  }

  @override
  void dispose() { _sleepTimer?.cancel(); _sleepFadeTimer?.cancel(); _statTimer?.cancel(); _spatialTimer?.cancel(); _noisySub?.cancel(); _sensorSub?.cancel(); _player.dispose(); _ambientPlayer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final glow = _glowScale;
    var filtered = _songs.where((s) {
      if (_filterTab == 1 && !s.favorite) return false;
      if (_selectedMood.isNotEmpty && s.mood != _selectedMood) return false;
      if (_query.isEmpty) return true;
      return s.title.toLowerCase().contains(_query) || s.artist.toLowerCase().contains(_query) || s.album.toLowerCase().contains(_query);
    }).toList();
    if (_sortAZ) filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final progress = _dur.inMilliseconds > 0 ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final activeMiniLyric = _showMiniLyric && _miniLyrics.isNotEmpty ? _miniLyrics.lastWhere((l) => l.at <= _pos, orElse: () => _miniLyrics.first).text : '';
    final artistGroups = <String, List<Song>>{};
    final albumGroups = <String, List<Song>>{};
    for (final s in filtered) {
      artistGroups.putIfAbsent(s.artist.isEmpty ? 'Unknown Artist' : s.artist, () => []).add(s);
      albumGroups.putIfAbsent(s.album.isEmpty ? 'Singles & Loose Tracks' : s.album, () => []).add(s);
    }

    return Stack(children: [
      Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.85), radius: 1.2, colors: [accent.withValues(alpha: (0.14 * glow).clamp(0.02, 0.36)), widget.amoledBlack ? Colors.black : const Color(0xFF0D0D12)])))),
      if (_bgPath != null) Positioned.fill(child: Opacity(opacity: 0.25, child: Image.file(File(_bgPath!), fit: BoxFit.cover))),
      if (!_batterySaver) Positioned.fill(child: AmbientParticleOverlay(mode: _particleMode, accent: widget.rawAccent)),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _selecting
            ? AppBar(backgroundColor: const Color(0xFF14141C), leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _selectedIds.clear())), title: Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(icon: Icon(Icons.favorite_rounded, color: accent), onPressed: _batchFavorite), IconButton(icon: const Icon(Icons.playlist_add_rounded), onPressed: _batchAddToPlaylist), IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _batchDelete)])
            : AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)), const SizedBox(width: 8), Flexible(child: Text(_bannerTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.8, fontSize: 19)))]), actions: [if (_batterySaver) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.battery_saver_rounded, color: Colors.amber, size: 20)), IconButton(tooltip: 'Scan Music Folder', icon: Icon(Icons.create_new_folder_rounded, color: accent), onPressed: _importFolder), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), onPressed: _importSongs, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add MP3s', style: TextStyle(fontWeight: FontWeight.w800))), const SizedBox(width: 12)]),
        body: _tab == 0
            ? Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: TextField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()), decoration: InputDecoration(hintText: 'Search songs, artists, or albums...', prefixIcon: Icon(Icons.search_rounded, color: accent.withValues(alpha: 0.8)), filled: true, fillColor: Colors.white.withValues(alpha: 0.06), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                if (_songs.isNotEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    ChoiceChip(label: Text('All (${_songs.length})'), selected: _filterTab == 0 && _browseMode == 0 && _selectedMood.isEmpty, onSelected: (_) => setState(() { _filterTab = 0; _browseMode = 0; _selectedMood = ''; })),
                    const SizedBox(width: 8),
                    ChoiceChip(label: Text('Liked (${_songs.where((s) => s.favorite).length})'), selected: _filterTab == 1 && _browseMode == 0 && _selectedMood.isEmpty, onSelected: (_) => setState(() { _filterTab = 1; _browseMode = 0; _selectedMood = ''; })),
                    ...kMoodTags.map((m) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(m), selected: _selectedMood == m, onSelected: (_) => setState(() { _browseMode = 0; _selectedMood = _selectedMood == m ? '' : m; })))),
                    if (_enableBrowseTabs) ...[const SizedBox(width: 8), ChoiceChip(label: const Text('Artists'), selected: _browseMode == 1, onSelected: (_) => setState(() => _browseMode = 1)), const SizedBox(width: 8), ChoiceChip(label: const Text('Albums'), selected: _browseMode == 2, onSelected: (_) => setState(() => _browseMode = 2))],
                    const SizedBox(width: 12),
                    IconButton(icon: Icon(Icons.sort_by_alpha_rounded, color: _sortAZ ? accent : Colors.white54), onPressed: () => setState(() => _sortAZ = !_sortAZ)),
                    IconButton(icon: Icon(Icons.shuffle_rounded, color: accent), onPressed: filtered.isEmpty ? null : () => _playFromQueue(filtered, 0, shuffleStart: true)),
                  ]))),
                Expanded(
                  child: _browseMode == 1
                      ? ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 120), children: artistGroups.entries.map((e) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)), child: ListTile(leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.2), child: Icon(Icons.person_rounded, color: accent)), title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${e.value.length} track(s)', style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.play_arrow_rounded), onTap: () => _playFromQueue(e.value, 0)))).toList())
                      : _browseMode == 2
                          ? ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 120), children: albumGroups.entries.map((e) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)), child: ListTile(leading: _buildArtBox(e.value.first, size: 44, radius: 10), title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${e.value.length} track(s)', style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.play_arrow_rounded), onTap: () => _playFromQueue(e.value, 0)))).toList())
                          : filtered.isEmpty
                              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.library_music_rounded, size: 58, color: accent.withValues(alpha: 0.5)), const SizedBox(height: 12), Text(_filterTab == 1 ? 'No Liked Tracks Yet' : 'No Matching Tracks', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(_filterTab == 1 ? 'Swipe right or tap the heart on any song' : 'Tap + Add MP3s or clear your active filter', style: const TextStyle(color: Colors.white60))]))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final s = filtered[i];
                                    final active = _current?.id == s.id;
                                    final isSelected = _selectedIds.contains(s.id);
                                    return Dismissible(
                                      key: ValueKey('swipe_${s.id}'),
                                      confirmDismiss: (dir) async { if (dir == DismissDirection.startToEnd) { await _toggleFavorite(s); } else { _playNextInQueue(s); } return false; },
                                      background: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.only(left: 20), alignment: Alignment.centerLeft, decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.favorite_rounded, color: accent)),
                                      secondaryBackground: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.only(right: 20), alignment: Alignment.centerRight, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.queue_play_next_rounded, color: Colors.white)),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(color: isSelected ? accent.withValues(alpha: 0.22) : (active ? accent.withValues(alpha: (0.12 * glow).clamp(0.05, 0.28)) : Colors.white.withValues(alpha: _frostedGlass ? 0.08 : 0.045)), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isSelected || active) ? accent.withValues(alpha: (0.55 * glow).clamp(0.2, 0.95)) : Colors.white10)),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                                          leading: isSelected ? CircleAvatar(backgroundColor: accent, child: const Icon(Icons.check_rounded, color: Colors.black)) : _buildArtBox(s, active: active),
                                          title: active ? MarqueeText(s.title, style: TextStyle(fontWeight: FontWeight.w800, color: accent)) : Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                                          subtitle: Text(s.mood.isNotEmpty ? '${s.artist} • ${s.mood}' : s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.mood.isNotEmpty ? accent.withValues(alpha: 0.85) : Colors.white60, fontSize: 13)),
                                          trailing: _selecting ? null : Row(mainAxisSize: MainAxisSize.min, children: [
                                            IconButton(icon: Icon(s.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: s.favorite ? accent : Colors.white38, size: 20), onPressed: () => _toggleFavorite(s)),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                              onSelected: (v) async {
                                                if (v == 'next') { _playNextInQueue(s); }
                                                else if (v == 'swap') { await _swapArtistAndTitle(s); }
                                                else if (v == 'mood') { await _setSongMood(s); }
                                                else if (v == 'pl') { final name = await _promptText('Playlist name'); if (name != null && name.isNotEmpty) { final ex = _playlists.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList(); if (ex.isNotEmpty) { if (!ex.first.songIds.contains(s.id)) ex.first.songIds.add(s.id); } else { _playlists.add(Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: [s.id])); } await _saveData(); setState(() {}); } }
                                                else if (v == 'ed') { await _editTrackDialog(s); }
                                                else if (v == 'art') { await _setSongArt(s); }
                                                else if (v == 'rm') { _songs.removeWhere((e) => e.id == s.id); if (File(s.path).existsSync()) await File(s.path).delete(); await _saveData(); setState(() {}); }
                                              },
                                              itemBuilder: (ctx) => const [PopupMenuItem(value: 'next', child: Text('Play Next')), PopupMenuItem(value: 'swap', child: Text('Swap Artist & Title')), PopupMenuItem(value: 'mood', child: Text('Set Vibe / Mood Tag')), PopupMenuItem(value: 'pl', child: Text('Add to playlist')), PopupMenuItem(value: 'ed', child: Text('Edit Title & Artist')), PopupMenuItem(value: 'art', child: Text('Set Gallery Cover Art')), PopupMenuItem(value: 'rm', child: Text('Delete'))],
                                            ),
                                          ]),
                                          onLongPress: () { HapticFeedback.mediumImpact(); setState(() { if (isSelected) { _selectedIds.remove(s.id); } else { _selectedIds.add(s.id); } }); },
                                          onTap: () { if (_selecting) { setState(() { if (isSelected) { _selectedIds.remove(s.id); } else { _selectedIds.add(s.id); } }); } else { _playFromQueue(filtered, i); } },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ])
            : _tab == 1
                ? Column(children: [
                    Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Text('Playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), onPressed: () async { final name = await _promptText('New playlist'); if (name != null && name.isNotEmpty) { _playlists.add(Playlist(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name, songIds: [])); await _saveData(); setState(() {}); } }, icon: const Icon(Icons.add_rounded), label: const Text('New', style: TextStyle(fontWeight: FontWeight.w800)))])),
                    Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: _playlists.length, itemBuilder: (ctx, i) {
                      final pl = _playlists[i];
                      final plSongs = pl.songIds.map((id) => _songs.where((s) => s.id == id).firstOrNull).whereType<Song>().toList();
                      return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: ListTile(leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.2), child: Icon(Icons.queue_music_rounded, color: accent)), title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${plSongs.length} songs', style: const TextStyle(color: Colors.white60)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { _playlists.removeAt(i); await _saveData(); setState(() {}); }), onTap: plSongs.isEmpty ? null : () => _playFromQueue(plSongs, 0)));
                    })),
                  ])
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const Text('Customize Type Shi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    const Text('ONE-TAP VIBE PACKS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: kVibePacks.map((vp) => GestureDetector(
                      onTap: () async { await widget.onSelectCustomAccent(vp.accent); await widget.onSelectFont(vp.fontIndex); await widget.onToggleAmoled(vp.amoled); setState(() { _frostedGlass = vp.frosted; _glowLevel = vp.glowLevel; }); await _saveData(); },
                      child: Container(width: 155, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: vp.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: vp.accent.withValues(alpha: 0.6))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(vp.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: vp.accent)), const SizedBox(height: 3), Text(vp.subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70))])),
                    )).toList())),
                    const SizedBox(height: 18),
                    const Text('ACCENT COLOR & CUSTOM PICKER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      ...List.generate(kAccentPalette.length, (i) { final c = kAccentPalette[i]; final sel = widget.rawAccent == c; return GestureDetector(onTap: () => widget.onSelectAccent(i), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: sel ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? accent : Colors.white24, width: sel ? 2 : 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 15, height: 15, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white54))), const SizedBox(width: 8), Text(kAccentNames[i], style: const TextStyle(fontWeight: FontWeight.w700))]))); }),
                      ActionChip(avatar: const Icon(Icons.colorize_rounded, size: 16), label: const Text('Custom RGB'), onPressed: () async { double hue = 180; await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) { final picked = HSLColor.fromAHSL(1, hue, 0.9, 0.55).toColor(); return AlertDialog(backgroundColor: const Color(0xFF16161C), title: const Text('Pick Custom Accent'), content: Column(mainAxisSize: MainAxisSize.min, children: [Container(height: 44, decoration: BoxDecoration(color: picked, borderRadius: BorderRadius.circular(12))), Slider(min: 0, max: 360, value: hue, onChanged: (v) => setD(() => hue = v))]), actions: [FilledButton(onPressed: () { widget.onSelectCustomAccent(picked); Navigator.pop(ctx); }, child: const Text('Apply'))]); })); }),
                    ]),
                    const SizedBox(height: 18),
                    const Text('FONT, GLOW & PARTICLE OVERLAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: List.generate(kFontNames.length, (i) => ChoiceChip(label: Text(kFontNames[i], style: TextStyle(fontFamily: kFontFamilies[i])), selected: widget.fontIndex == i, onSelected: (_) => widget.onSelectFont(i)))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: List.generate(kGlowNames.length, (i) => ChoiceChip(label: Text('Glow: ${kGlowNames[i]}'), selected: _glowLevel == i, onSelected: (_) async { setState(() => _glowLevel = i); await _saveData(); }))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: kParticleModes.map((pm) => ChoiceChip(label: Text(pm), selected: _particleMode == pm, onSelected: (_) async { setState(() => _particleMode = pm); await _saveData(); })).toList()),
                    const SizedBox(height: 18),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('AMOLED Pure Black (#000000)', style: TextStyle(fontWeight: FontWeight.w700)), value: widget.amoledBlack, onChanged: widget.onToggleAmoled),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Tinted Frosted Glass Cards', style: TextStyle(fontWeight: FontWeight.w700)), value: _frostedGlass, onChanged: (v) async { setState(() => _frostedGlass = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Beat-Reactive Bass Glow', style: TextStyle(fontWeight: FontWeight.w700)), value: _beatReactive, onChanged: (v) async { setState(() => _beatReactive = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('ASCII / Matrix Visualizer', style: TextStyle(fontWeight: FontWeight.w700)), value: _matrixVisualizer, onChanged: (v) async { setState(() => _matrixVisualizer = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('3D Gyroscope Cover Tilt', style: TextStyle(fontWeight: FontWeight.w700)), value: _gyroTilt, onChanged: (v) async { setState(() => _gyroTilt = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Text('Battery Saver Mode ($_batteryLevel%)', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Auto-enables below 20% battery'), value: _batterySaver, onChanged: (v) => setState(() => _batterySaver = v)),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Artist & Album Tabs in Library', style: TextStyle(fontWeight: FontWeight.w700)), value: _enableBrowseTabs, onChanged: (v) async { setState(() { _enableBrowseTabs = v; if (!v) _browseMode = 0; }); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Auto-Pause on Headphone Unplug', style: TextStyle(fontWeight: FontWeight.w700)), value: _autoPauseNoisy, onChanged: (v) async { setState(() => _autoPauseNoisy = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Shake Phone to Skip / Shuffle', style: TextStyle(fontWeight: FontWeight.w700)), value: _shakeToSkip, onChanged: (v) async { setState(() => _shakeToSkip = v); await _saveData(); }),
                    const SizedBox(height: 8),
                    SwitchListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Smart Volume Normalizer', style: TextStyle(fontWeight: FontWeight.w700)), value: _volumeNormalizer, onChanged: (v) async { setState(() => _volumeNormalizer = v); await _player.setVolume(v ? 0.85 : 1.0); await _saveData(); }),
                    const SizedBox(height: 16),
                    ListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), leading: Icon(Icons.receipt_long_rounded, color: accent), title: const Text('Monthly Listening Receipt', style: TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54), onTap: _openMonthlyReceiptSheet),
                    const SizedBox(height: 8),
                    ListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), leading: Icon(Icons.wallpaper_rounded, color: accent), title: const Text('Set Custom Background Wallpaper'), onTap: _pickWallpaper),
                    const SizedBox(height: 8),
                    ListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), leading: Icon(Icons.cleaning_services_rounded, color: accent), title: const Text('Find & Remove Duplicate Tracks'), onTap: _removeDuplicates),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _exportBackup, icon: const Icon(Icons.upload_file_rounded, size: 18), label: const Text('Export Backup'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: _restoreBackup, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Restore Backup')))]),
                    const SizedBox(height: 20),
                    const Text('APP HEADER TITLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white60)),
                    const SizedBox(height: 8),
                    ListTile(tileColor: Colors.white.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), leading: Icon(Icons.edit_rounded, color: accent), title: Text(_bannerTitle, style: const TextStyle(fontWeight: FontWeight.w800)), onTap: () async { final name = await _promptText('App Header Title', initial: _bannerTitle); if (name != null && name.isNotEmpty) { setState(() => _bannerTitle = name); await _saveData(); } }),
                    const SizedBox(height: 24),
                    Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withValues(alpha: 0.38))), child: Text('made by Aakas', style: TextStyle(fontSize: 13, letterSpacing: 1.6, color: accent, fontWeight: FontWeight.w800)))),
                  ]),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_current != null)
            GestureDetector(
              onTap: _openNowPlaying,
              onHorizontalDragEnd: (d) { final v = d.primaryVelocity ?? 0; if (v < -250) { HapticFeedback.lightImpact(); _next(); } else if (v > 250) { HapticFeedback.lightImpact(); _prev(); } },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8), clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: const Color(0xFF181822).withValues(alpha: 0.92), borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: (0.4 * glow).clamp(0.15, 0.9)))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.fromLTRB(12, 8, 8, 6), child: Row(children: [
                    _buildArtBox(_current!, size: 42, radius: 10, active: true),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [MarqueeText(_current!.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(activeMiniLyric.isNotEmpty ? activeMiniLyric : _current!.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: activeMiniLyric.isNotEmpty ? accent : Colors.white60))])),
                    IconButton(icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, size: 34, color: accent), onPressed: () => _playing ? _player.pause() : _player.play()),
                    IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: _next),
                  ])),
                  LinearProgressIndicator(value: progress, minHeight: 2.5, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(accent)),
                ]),
              ),
            ),
          NavigationBar(backgroundColor: const Color(0xFF0A0A0E), indicatorColor: accent.withValues(alpha: 0.22), selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Library'), NavigationDestination(icon: Icon(Icons.queue_music_rounded), label: 'Playlists'), NavigationDestination(icon: Icon(Icons.palette_rounded), label: 'Customize')]),
        ]),
      ),
    ]);
  }

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({
    super.key, required this.rawAccent, required this.accent, required this.isFullBlackAccent, required this.glowScale,
    required this.gyroX, required this.gyroY, required this.beatReactive, required this.matrixVisualizer, required this.particleMode, required this.batterySaver,
    required this.getSong, required this.getQueue, required this.getQueueIndex, required this.getPlaying, required this.getPos, required this.getDur,
    required this.getShuffle, required this.getLoop, required this.getSpeed, required this.getPitch, required this.getSlowedReverb,
    required this.getVocalMute, required this.getSpatial8D, required this.getLofiMode, required this.getAmbientOverlay,
    required this.getSleepMinutes, required this.getLoopA, required this.getLoopB, required this.player,
    required this.onTogglePlay, required this.onToggleFavorite, required this.onNext, required this.onPrev, required this.onSeekBy,
    required this.onToggleSlowedReverb, required this.onToggleVocalMute, required this.onToggleSpatial8D, required this.onToggleLofi, required this.onCycleAmbient,
    required this.onOpenEq, required this.onSetLoopA, required this.onSetLoopB, required this.onClearAB,
    required this.onJumpToQueueIndex, required this.onReorderQueue, required this.onToggleShuffle, required this.onCycleLoop,
    required this.onSetSpeed, required this.onSetPitch, required this.onSetSleep,
  });

  final Color rawAccent, accent;
  final bool isFullBlackAccent, beatReactive, matrixVisualizer, batterySaver;
  final double glowScale;
  final double Function() gyroX, gyroY;
  final String particleMode;
  final Song? Function() getSong;
  final List<Song> Function() getQueue;
  final int Function() getQueueIndex;
  final bool Function() getPlaying, getShuffle, getSlowedReverb, getVocalMute, getSpatial8D, getLofiMode;
  final Duration Function() getPos, getDur;
  final LoopMode Function() getLoop;
  final double Function() getSpeed, getPitch;
  final String Function() getAmbientOverlay;
  final int? Function() getSleepMinutes;
  final Duration? Function() getLoopA, getLoopB;
  final AudioPlayer player;
  final VoidCallback onTogglePlay, onToggleFavorite, onNext, onPrev, onOpenEq, onClearAB, onToggleShuffle;
  final Future<void> Function(int) onSeekBy, onJumpToQueueIndex;
  final Future<void> Function() onToggleSlowedReverb, onToggleVocalMute, onToggleSpatial8D, onToggleLofi, onCycleAmbient, onCycleLoop;
  final void Function(Duration) onSetLoopA, onSetLoopB;
  final void Function(int, int) onReorderQueue;
  final Future<void> Function(double) onSetSpeed, onSetPitch;
  final void Function(int?) onSetSleep;

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();

class _NowPlayingSheetState extends State<NowPlayingSheet> with TickerProviderStateMixin {
  List<LyricLine> _lyrics = [];
  String _plainLyrics = '';
  bool _loadingLyrics = false, _fullScreenLyrics = false, _fullBleedCover = false, _showRemaining = false, _syncingMode = false;
  int _artSkin = 0;
  double _dragTilt = 0.0;
  String _seekFlash = '';
  List<String> _syncLines = [];
  List<LyricLine> _recordedSync = [];
  String? _loadedSongId;
  int _lastActiveIdx = -1;
  Timer? _uiTick;
  final ScrollController _lyricScroll = ScrollController();
  late final AnimationController _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  late final AnimationController _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _uiTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (widget.getPlaying()) { if (!_spinCtrl.isAnimating) _spinCtrl.repeat(); if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true); }
      else { if (_spinCtrl.isAnimating) _spinCtrl.stop(); if (_pulseCtrl.isAnimating) _pulseCtrl.stop(); }
      final cur = widget.getSong();
      if (cur != null && cur.id != _loadedSongId) { _syncingMode = false; _fetchLyrics(cur); }
      final idx = _lyrics.lastIndexWhere((l) => l.at <= widget.getPos());
      if (idx != _lastActiveIdx && idx >= 0 && _lyricScroll.hasClients) {
        _lastActiveIdx = idx;
        _lyricScroll.animateTo((idx * 42.0 - 70).clamp(0.0, _lyricScroll.position.maxScrollExtent), duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
      setState(() {});
    });
    if (widget.getSong() != null) _fetchLyrics(widget.getSong()!);
  }

  String _stripJunk(String s) => s.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _fetchLyrics(Song song, {String? customQuery}) async {
    _loadedSongId = song.id;
    _lastActiveIdx = -1;
    setState(() { _loadingLyrics = true; _lyrics = []; _plainLyrics = ''; });
    final prefs = await SharedPreferences.getInstance();
    if (customQuery == null) {
      final cached = prefs.getString('lyrics_${song.id}');
      if (cached != null && cached.isNotEmpty) { final d = jsonDecode(cached) as Map<String, dynamic>; _applyLyricPayload(d['synced'] ?? '', d['plain'] ?? ''); if (mounted) setState(() => _loadingLyrics = false); return; }
    }
    try {
      final q = customQuery ?? '${_stripJunk(song.title)} ${song.artist == 'Unknown Artist' ? '' : _stripJunk(song.artist)}'.trim();
      final res = await http.get(Uri.parse('https://lrclib.net{Uri.encodeComponent(q)}'), headers: {'User-Agent': 'TypeShiApp/1.0'}).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          final best = list.firstWhere((e) => (e['syncedLyrics'] ?? '').toString().isNotEmpty, orElse: () => list.first);
          final synced = (best['syncedLyrics'] ?? '').toString(), plain = (best['plainLyrics'] ?? '').toString();
          await prefs.setString('lyrics_${song.id}', jsonEncode({'synced': synced, 'plain': plain}));
          _applyLyricPayload(synced, plain);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLyrics = false);
  }

  void _applyLyricPayload(String synced, String plain) {
    final parsed = <LyricLine>[];
    final rx = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');
    for (final line in synced.split('\n')) {
      final m = rx.firstMatch(line);
      if (m != null && m.group(4)!.trim().isNotEmpty) parsed.add(LyricLine(Duration(minutes: int.parse(m.group(1)!), seconds: int.parse(m.group(2)!), milliseconds: int.parse(m.group(3)!.padRight(3, '0').substring(0, 3))), m.group(4)!.trim()));
    }
    if (mounted) setState(() { _lyrics = parsed; _plainLyrics = (parsed.isEmpty && plain.isNotEmpty) ? plain : ''; });
  }

  void _startSyncMode() {
    final lines = (_plainLyrics.isNotEmpty ? _plainLyrics : _lyrics.map((e) => e.text).join('\n')).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isNotEmpty) setState(() { _syncLines = lines; _recordedSync = []; _syncingMode = true; });
  }

  Future<void> _recordNextSyncLine(Song song) async {
    if (_recordedSync.length >= _syncLines.length) return;
    HapticFeedback.lightImpact();
    _recordedSync.add(LyricLine(widget.getPos(), _syncLines[_recordedSync.length]));
    if (_recordedSync.length == _syncLines.length) {
      final lrc = _recordedSync.map((l) => '[${l.at.inMinutes.toString().padLeft(2, '0')}:${(l.at.inSeconds % 60).toString().padLeft(2, '0')}.${((l.at.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0')}] ${l.text}').join('\n');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lyrics_${song.id}', jsonEncode({'synced': lrc, 'plain': _syncLines.join('\n')}));
      setState(() { _lyrics = List<LyricLine>.from(_recordedSync); _plainLyrics = ''; _syncingMode = false; });
    } else { setState(() {}); }
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() { _uiTick?.cancel(); _lyricScroll.dispose(); _spinCtrl.dispose(); _pulseCtrl.dispose(); super.dispose(); }

  Widget _buildLyricsCard(Song song, int activeIdx, {required double height}) {
    final pos = widget.getPos();
    return Container(
      height: height, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(22), border: Border.all(color: widget.accent.withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_syncingMode ? 'SYNC MODE' : 'LYRICS', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 11, color: widget.accent))),
          if (!_syncingMode && (_plainLyrics.isNotEmpty || _lyrics.isNotEmpty)) IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), icon: const Icon(Icons.timer_rounded, size: 18), onPressed: _startSyncMode),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), icon: const Icon(Icons.content_paste_rounded, size: 18), onPressed: () async { final clip = await Clipboard.getData('text/plain'); final txt = (clip?.text ?? '').trim(); if (txt.isNotEmpty) { final p = await SharedPreferences.getInstance(); await p.setString('lyrics_${song.id}', jsonEncode({'synced': '', 'plain': txt})); _syncingMode = false; _applyLyricPayload('', txt); } }),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), icon: const Icon(Icons.search_rounded, size: 18), onPressed: () async { final c = TextEditingController(text: '${song.artist == 'Unknown Artist' ? '' : '${song.artist} '}${song.title}'); final q = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF16161C), title: const Text('Search Lyrics'), content: TextField(controller: c, autofocus: true), actions: [FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Search'))])); if (q != null && q.isNotEmpty) await _fetchLyrics(song, customQuery: q); }),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 34, minHeight: 32), icon: Icon(_fullScreenLyrics ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 22, color: widget.accent), tooltip: 'Full-Screen Lyrics', onPressed: () => setState(() => _fullScreenLyrics = !_fullScreenLyrics)),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: _syncingMode
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Line ${_recordedSync.length + 1}/${_syncLines.length}', style: const TextStyle(fontSize: 12, color: Colors.white54)), const SizedBox(height: 8), Text(_recordedSync.length < _syncLines.length ? _syncLines[_recordedSync.length] : 'Done!', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: widget.accent)), const SizedBox(height: 12), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.black), onPressed: () => _recordNextSyncLine(song), icon: const Icon(Icons.touch_app_rounded), label: const Text('Tap on Beat'))])
              : _loadingLyrics
                  ? Center(child: CircularProgressIndicator(color: widget.accent))
                  : _lyrics.isNotEmpty
                      ? ListView.builder(controller: _lyricScroll, itemCount: _lyrics.length, itemBuilder: (_, i) {
                          final active = i == activeIdx;
                          final sMs = _lyrics[i].at.inMilliseconds, eMs = (i + 1 < _lyrics.length) ? _lyrics[i + 1].at.inMilliseconds : (sMs + 3000);
                          final fill = active ? ((pos.inMilliseconds - sMs) / (eMs - sMs).clamp(400, 12000)).clamp(0.0, 1.0) : 0.0;
                          return GestureDetector(onTap: () => widget.player.seek(_lyrics[i].at), child: Container(margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: active ? widget.accent.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: active ? ShaderMask(shaderCallback: (b) => LinearGradient(stops: [fill, (fill + 0.06).clamp(0.0, 1.0)], colors: [widget.accent, Colors.white54]).createShader(b), child: Text(_lyrics[i].text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))) : Text(_lyrics[i].text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white54))));
                        })
                      : _plainLyrics.isNotEmpty
                          ? SingleChildScrollView(child: Text(_plainLyrics, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)))
                          : const Center(child: Text('No lyrics found.\nTap search or paste lyrics.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
        ),
      ]),
    );
  }

  Widget _buildArtSkins(Song song, Color accent, bool hasArt) {
    final glow = widget.glowScale;
    final square = Container(width: 220, height: 220, decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), image: hasArt ? DecorationImage(image: FileImage(File(song.artPath!)), fit: BoxFit.cover) : null), child: hasArt ? null : ProceduralNeonCover(seedText: '${song.title}${song.artist}', accent: widget.rawAccent, size: 220, radius: 26));
    final vinyl = RotationTransition(turns: _spinCtrl, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF111116), border: Border.all(color: Colors.white12, width: 6)), child: Center(child: Container(width: 102, height: 102, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 3), image: hasArt ? DecorationImage(image: FileImage(File(song.artPath!)), fit: BoxFit.cover) : null), child: hasArt ? null : ProceduralNeonCover(seedText: song.title, accent: widget.rawAccent, size: 102, radius: 51)))));
    final ipod2000s = Container(width: 215, height: 270, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFE6E6EC), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white, width: 2)), child: Column(children: [
      Container(height: 102, width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF9BB4C8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black54, width: 1.5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('iPod • Type Shi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black87)),
        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black)),
        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        LinearProgressIndicator(value: widget.getDur().inMilliseconds > 0 ? (widget.getPos().inMilliseconds / widget.getDur().inMilliseconds).clamp(0.0, 1.0) : 0, minHeight: 5, backgroundColor: Colors.black26, valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87)),
      ])),
      const Spacer(),
      Container(width: 114, height: 114, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Stack(alignment: Alignment.center, children: [
        const Positioned(top: 8, child: Text('MENU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black54))),
        Positioned(left: 8, child: GestureDetector(onTap: widget.onPrev, child: const Icon(Icons.fast_rewind_rounded, size: 18, color: Colors.black54))),
        Positioned(right: 8, child: GestureDetector(onTap: widget.onNext, child: const Icon(Icons.fast_forward_rounded, size: 18, color: Colors.black54))),
        Positioned(bottom: 8, child: GestureDetector(onTap: widget.onTogglePlay, child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.black54))),
        GestureDetector(onTap: widget.onTogglePlay, child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFD4D4DC), shape: BoxShape.circle))),
      ])),
    ]));

    final chosen = _artSkin == 1 ? vinyl : (_artSkin == 2 ? ipod2000s : square);
    return GestureDetector(
      onTap: () => setState(() => _artSkin = (_artSkin + 1) % 3),
      onDoubleTapDown: (d) { final left = d.localPosition.dx < 110; HapticFeedback.lightImpact(); widget.onSeekBy(left ? -10 : 10); setState(() => _seekFlash = left ? '-10s' : '+10s'); Future.delayed(const Duration(milliseconds: 650), () { if (mounted) setState(() => _seekFlash = ''); }); },
      onHorizontalDragUpdate: (d) => setState(() => _dragTilt = (_dragTilt + d.delta.dx * 0.004).clamp(-0.35, 0.35)),
      onHorizontalDragEnd: (d) { final v = d.primaryVelocity ?? 0; setState(() => _dragTilt = 0); if (v < -250) widget.onNext(); if (v > 250) widget.onPrev(); },
      child: Column(children: [
        Transform(alignment: Alignment.center, transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(_dragTilt + widget.gyroY())..rotateX(widget.gyroX()), child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: _pulseCtrl, builder: (_, child) {
            final beat = (widget.getPlaying() && widget.beatReactive && !widget.batterySaver) ? (14.0 + 22.0 * _pulseCtrl.value) : 10.0;
            return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(_artSkin == 1 ? 140 : 30), border: Border.all(color: accent.withValues(alpha: 0.5), width: 2), boxShadow: [BoxShadow(color: accent.withValues(alpha: (0.28 * glow).clamp(0.05, 0.7)), blurRadius: beat * glow, spreadRadius: 2 * glow)]), child: child);
          }, child: chosen),
          if (_seekFlash.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)), child: Text(_seekFlash, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent))),
        ])),
        const SizedBox(height: 6),
        Text('Tap skin (${['Cover', 'Vinyl', '2000s iPod'][_artSkin]}) • Double-tap sides ±10s', style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.getSong();
    if (song == null) return const SizedBox.shrink();
    final accent = widget.accent;
    final pos = widget.getPos(), dur = widget.getDur(), playing = widget.getPlaying();
    final shuffle = widget.getShuffle(), loop = widget.getLoop(), speed = widget.getSpeed(), pitch = widget.getPitch();
    final slowed = widget.getSlowedReverb(), vocalMute = widget.getVocalMute(), spatial = widget.getSpatial8D(), lofi = widget.getLofiMode();
    final amb = widget.getAmbientOverlay(), sleepMins = widget.getSleepMinutes(), loopA = widget.getLoopA(), loopB = widget.getLoopB();
    final activeIdx = _lyrics.lastIndexWhere((l) => l.at <= pos);
    final hasArt = song.artPath != null && File(song.artPath!).existsSync();
    final remaining = dur > pos ? dur - pos : Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30), onPressed: () => Navigator.pop(context)),
        title: const Text('NOW PLAYING', style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'Full-Bleed Cinema Cover', icon: Icon(Icons.movie_filter_rounded, color: _fullBleedCover ? accent : Colors.white), onPressed: () => setState(() => _fullBleedCover = !_fullBleedCover)),
          IconButton(tooltip: 'Auto-EQ & DSP', icon: const Icon(Icons.equalizer_rounded), onPressed: widget.onOpenEq),
          IconButton(tooltip: 'Circular Sleep Dial', icon: Icon(Icons.bedtime_rounded, color: sleepMins != null ? Colors.amber : Colors.white), onPressed: () async { final res = await showDialog<int>(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF16161C), title: const Text('Sleep Timer Dial'), content: CircularSleepDial(accent: accent, initialMinutes: sleepMins ?? 20))); if (res != null) widget.onSetSleep(res == 0 ? null : res); }),
        ],
      ),
      body: Stack(children: [
        if (_fullBleedCover)
          Positioned(top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.65, child: Stack(fit: StackFit.expand, children: [
            hasArt ? Image.file(File(song.artPath!), fit: BoxFit.cover) : ProceduralNeonCover(seedText: '${song.title}${song.artist}', accent: widget.rawAccent, size: 420, radius: 0),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black38, Colors.transparent, Colors.black], stops: [0.0, 0.45, 1.0]))),
          ]))
        else if (hasArt)
          Positioned.fill(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35), child: Opacity(opacity: 0.32, child: Image.file(File(song.artPath!), fit: BoxFit.cover)))),
        if (!widget.batterySaver) Positioned.fill(child: AmbientParticleOverlay(mode: widget.particleMode, accent: widget.rawAccent)),
        SafeArea(
          child: _fullScreenLyrics
              ? Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: Column(children: [
                  Expanded(child: _buildLyricsCard(song, activeIdx, height: double.infinity)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 32), onPressed: widget.onPrev), FloatingActionButton(backgroundColor: accent, foregroundColor: Colors.black, onPressed: widget.onTogglePlay, child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 34)), IconButton(icon: const Icon(Icons.skip_next_rounded, size: 32), onPressed: widget.onNext)]),
                ]))
              : ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 20), children: [
                  if (_fullBleedCover) SizedBox(height: MediaQuery.of(context).size.height * 0.36) else Center(child: _buildArtSkins(song, accent, hasArt)),
                  const SizedBox(height: 12),
                  if (widget.matrixVisualizer && !widget.batterySaver) ...[MatrixVisualizerBar(accent: accent, playing: playing), const SizedBox(height: 10)],
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [MarqueeText(song.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white60))])),
                    IconButton(icon: Icon(song.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: song.favorite ? accent : Colors.white54), onPressed: widget.onToggleFavorite),
                  ]),
                  const SizedBox(height: 6),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    ChoiceChip(label: const Text('Vocal Mute'), selected: vocalMute, onSelected: (_) => widget.onToggleVocalMute()),
                    const SizedBox(width: 6),
                    ChoiceChip(label: const Text('8D Spatial'), selected: spatial, onSelected: (_) => widget.onToggleSpatial8D()),
                    const SizedBox(width: 6),
                    ChoiceChip(label: const Text('Lofi'), selected: lofi, onSelected: (_) => widget.onToggleLofi()),
                    const SizedBox(width: 6),
                    ActionChip(label: Text('Ambient: $amb'), onPressed: widget.onCycleAmbient),
                    const SizedBox(width: 6),
                    ChoiceChip(label: const Text('Slow+Rev'), selected: slowed, onSelected: (_) => widget.onToggleSlowedReverb()),
                    const SizedBox(width: 6),
                    ActionChip(label: Text('Speed ${speed}x'), onPressed: () => widget.onSetSpeed(speed == 1.0 ? 1.25 : (speed == 1.25 ? 1.5 : (speed == 1.5 ? 0.75 : 1.0)))),
                    const SizedBox(width: 6),
                    ActionChip(label: Text('Pitch ${pitch}x'), onPressed: () => widget.onSetPitch(pitch == 1.0 ? 1.15 : (pitch == 1.15 ? 1.3 : (pitch == 1.3 ? 0.85 : 1.0)))),
                  ])),
                  Slider(value: dur.inMilliseconds > 0 ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0, max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1, onChanged: (v) => widget.player.seek(Duration(milliseconds: v.toInt()))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    Row(children: [
                      InkWell(onTap: () => widget.onSetLoopA(pos), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: loopA != null ? accent.withValues(alpha: 0.22) : Colors.white10, borderRadius: BorderRadius.circular(8)), child: Text(loopA != null ? 'A ${_fmt(loopA)}' : 'Set A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: loopA != null ? accent : Colors.white60)))),
                      const SizedBox(width: 6),
                      InkWell(onTap: () => widget.onSetLoopB(pos), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: loopB != null ? accent.withValues(alpha: 0.22) : Colors.white10, borderRadius: BorderRadius.circular(8)), child: Text(loopB != null ? 'B ${_fmt(loopB)}' : 'Set B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: loopB != null ? accent : Colors.white60)))),
                      if (loopA != null || loopB != null) ...[const SizedBox(width: 4), InkWell(onTap: widget.onClearAB, child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54))],
                    ]),
                    GestureDetector(onTap: () => setState(() => _showRemaining = !_showRemaining), child: Text(_showRemaining ? '-${_fmt(remaining)}' : _fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.white60))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(icon: Icon(Icons.shuffle_rounded, color: shuffle ? accent : Colors.white38, size: 22), onPressed: widget.onToggleShuffle), IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 32), onPressed: widget.onPrev)])),
                    FloatingActionButton.large(backgroundColor: accent, foregroundColor: Colors.black, onPressed: widget.onTogglePlay, child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42)),
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(icon: const Icon(Icons.skip_next_rounded, size: 32), onPressed: widget.onNext), IconButton(icon: Icon(loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: loop != LoopMode.off ? accent : Colors.white38, size: 22), onPressed: widget.onCycleLoop)])),
                  ]),
                  const SizedBox(height: 18),
                  _buildLyricsCard(song, activeIdx, height: 255),
                ]),
        ),
      ]),
    );
  }













