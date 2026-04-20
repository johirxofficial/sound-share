import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
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
      title: 'SoundShare V2.0',
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
  String _ipAddress = "Detecting IP...";
  bool _isServerRunning = false;
  String _statusMessage = "System Ready (V2.0.0)";
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamController<List<int>>? _audioStreamController;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    _fetchNativeIP();
  }

  // 100% Native Dart Code to find correct Local IP
  Future<void> _fetchNativeIP() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            if (mounted) {
              setState(() => _ipAddress = addr.address);
            }
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ipAddress = "127.0.0.1 (Offline)");
      }
    }
  }

  Future<void> _startServer() async {
    try {
      _audioStreamController = StreamController<List<int>>.broadcast();
      
      if (await _audioRecorder.hasPermission()) {
        // Encoding as WAV so Chrome/Safari on mobile can play it easily
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 2,
        ));
        stream.listen((data) {
          if (_audioStreamController?.isClosed == false) {
            _audioStreamController?.add(data);
          }
        });
      } else {
        throw Exception("Microphone/Stereo Mix Permission Denied by Windows!");
      }

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
            'Cache-Control': 'no-cache, no-store, must-revalidate',
          });
        }
        return Response.internalServerError();
      });

      _server = await shelf_io.serve(router.call, '0.0.0.0', 8080);
      
      setState(() {
        _isServerRunning = true;
        _statusMessage = "🔴 Broadcasting Live on Port 8080";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error Starting Server: $e"), backgroundColor: Colors.redAccent)
      );
      _stopServer();
    }
  }

  Future<void> _stopServer() async {
    await _audioRecorder.stop();
    await _audioStreamController?.close();
    await _server?.close(force: true);
    
    setState(() {
      _isServerRunning = false;
      _statusMessage = "Server Stopped";
    });
  }

  @override
  void dispose() {
    if (_isServerRunning) _stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speaker_group_outlined, size: 90, color: Color(0xFF38BDF8)),
            const SizedBox(height: 20),
            const Text("Ask users to visit:", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: SelectableText(
                "http://$_ipAddress:8080",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 15),
            Text(_statusMessage, style: TextStyle(color: _isServerRunning ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isServerRunning ? _stopServer : _startServer,
              icon: Icon(_isServerRunning ? Icons.stop_circle : Icons.play_arrow, size: 28),
              label: Text(_isServerRunning ? "STOP STREAMING" : "START SERVER"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.redAccent : const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}