// lib/main.dart
import 'dart:async';
import 'dart:io'; // 🔥 FIXED: Added missing import for HttpServer
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router; // 🔥 FIXED: Aliased to prevent Router conflict
import 'package:record/record.dart';
import 'web_ui.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SoundShareApp());
}

class SoundShareApp extends StatelessWidget {
  const SoundShareApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundShare by Johirxofficial',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF38BDF8),
      ),
      home: const ServerControlScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ServerControlScreen extends StatefulWidget {
  const ServerControlScreen({Key? key}) : super(key: key);

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  String _ipAddress = "Loading...";
  bool _isServerRunning = false;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamController<List<int>>? _audioStreamController;
  late final HttpServer _server;

  @override
  void initState() {
    super.initState();
    _fetchIP();
  }

  Future<void> _fetchIP() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    setState(() {
      _ipAddress = ip ?? "127.0.0.1 (No LAN detected)";
    });
  }

  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await _stopServer();
    } else {
      await _startServer();
    }
  }

  Future<void> _startServer() async {
    _audioStreamController = StreamController<List<int>>.broadcast();
    
    if (await _audioRecorder.hasPermission()) {
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 2,
      ));
      
      stream.listen((data) {
        if (_audioStreamController?.isClosed == false) {
          _audioStreamController?.add(data);
        }
      });
    }

    // 🔥 FIXED: Using the aliased router
    final router = shelf_router.Router(); 
    
    router.get('/', (Request request) {
      return Response.ok(webInterfaceHTML, headers: {'Content-Type': 'text/html'});
    });

    router.get('/stream', (Request request) {
      if (_audioStreamController != null) {
        return Response.ok(_audioStreamController!.stream, headers: {
          'Content-Type': 'audio/wav',
          'Transfer-Encoding': 'chunked',
          'Access-Control-Allow-Origin': '*',
        });
      }
      return Response.internalServerError();
    });

    _server = await shelf_io.serve(router.call, '0.0.0.0', 8080);
    
    setState(() {
      _isServerRunning = true;
    });
  }

  Future<void> _stopServer() async {
    await _audioRecorder.stop();
    await _audioStreamController?.close();
    await _server.close(force: true);
    
    setState(() {
      _isServerRunning = false;
    });
  }

  @override
  void dispose() {
    _stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ Shadow SoundShare'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.router_outlined, size: 80, color: Color(0xFF38BDF8)),
            const SizedBox(height: 20),
            const Text(
              "Ask users to visit this link:",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1),
              ),
              child: Text(
                "http://$_ipAddress:8080",
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: _toggleServer,
              icon: Icon(_isServerRunning ? Icons.stop_circle : Icons.play_arrow),
              label: Text(_isServerRunning ? "STOP STREAMING" : "START SERVER"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.redAccent : const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            if (_isServerRunning) ...[
              const SizedBox(height: 30),
              const Text("🔴 Live & Broadcasting...", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
            ]
          ],
        ),
      ),
    );
  }
}
