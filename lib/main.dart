import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const ScrollRecorderApp());
}

class ScrollRecorderApp extends StatelessWidget {
  const ScrollRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScrollRecorder',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
      ),
      home: const RecorderPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScrollEvent {
  final double position;
  final DateTime timestamp;

  ScrollEvent({
    required this.position,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'position': position,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ScrollEvent.fromMap(Map<String, dynamic> m) => ScrollEvent(
    position: m['position'],
    timestamp: DateTime.parse(m['timestamp']),
  );
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final ScrollController _controller = ScrollController();
  bool _recording = false;
  bool _playing = false;
  List<ScrollEvent> _events = [];
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  int _playbackIndex = 0;
  final int _recordIntervalMs = 20;
  final int _playbackIntervalMs = 16;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _events = [];
    });
    final startTime = DateTime.now();
    _recordingTimer = Timer.periodic(
      Duration(milliseconds: _recordIntervalMs),
      (timer) {
        if (!_recording) return;
        if (_controller.hasClients) {
          _events.add(ScrollEvent(
            position: _controller.position.pixels,
            timestamp: DateTime.now(),
          ));
        }
      },
    );
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _recording = false;
    });
    _saveEvents();
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _events.map((e) => _mapToString(e.toMap())).toList();
    await prefs.setStringList('scroll_events', data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.green[800],
            content: Text('Tersimpan ${_events.length} event scroll')),
      );
    }
  }

  String _mapToString(Map<String, dynamic> m) {
    return '${m['position']}|${m['timestamp']}';
  }

  Map<String, dynamic> _stringToMap(String s) {
    final parts = s.split('|');
    return {
      'position': double.parse(parts[0]),
      'timestamp': parts[1],
    };
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('scroll_events') ?? [];
    setState(() {
      _events = data.map((s) => ScrollEvent.fromMap(_stringToMap(s))).toList();
    });
    if (mounted && _events.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.blue[800],
            content: Text('Dimuat ${_events.length} event scroll')),
      );
    }
  }

  void _startPlayback() {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Tidak ada data scroll tersimpan')),
      );
      return;
    }
    setState(() {
      _playing = true;
      _playbackIndex = 0;
    });
    if (_controller.hasClients) {
      _controller.jumpTo(_events[0].position);
    }
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: _playbackIntervalMs),
      (timer) {
        if (!_playing) return;
        if (_playbackIndex >= _events.length) {
          timer.cancel();
          setState(() => _playing = false);
          return;
        }
        final target = _events[_playbackIndex].position;
        if (_controller.hasClients) {
          _controller.jumpTo(target);
        }
        _playbackIndex += 1;
      },
    );
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() => _playing = false);
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScrollRecorder'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel kontrol
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _recording ? _stopRecording : _startRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(_recording ? 'Stop Rekam' : 'Rekam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _recording ? Colors.red : Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _playing ? _stopPlayback : _startPlayback,
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(_playing ? 'Stop Putar' : 'Putar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _playing ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Info status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF252525),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${_recording ? "Merekam..." : _playing ? "Memutar..." : "Siap"}',
                  style: TextStyle(
                    color: _recording
                        ? Colors.red
                        : _playing
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
                Text('Event: ${_events.length}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          // Area scroll
          Expanded(
            child: Scrollbar(
              controller: _controller,
              child: ListView.builder(
                controller: _controller,
                itemCount: 120,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF2D2D2D + (index % 3) * 0x111111),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Item ke-${index + 1}\nScroll ke atas/bawah untuk rekam gerakan',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
