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
      title: 'SoundShare Pro',
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
  String _ipAddress = "Finding IP...";
  bool _isServerRunning = false;
  String _statusMessage = "System Ready";
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamController<List<int>>? _audioStreamController;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    _fetchIP();
  }

  Future<void> _fetchIP() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            setState(() => _ipAddress = addr.address);
            return;
          }
        }
      }
    } catch (e) {
      setState(() => _ipAddress = "127.0.0.1");
    }
  }

  Future<void> _startServer() async {
    try {
      _audioStreamController = StreamController<List<int>>.broadcast();
      
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 2,
        ));
        stream.listen((data) {
          if (_audioStreamController?.isClosed == false) _audioStreamController?.add(data);
        });
      } else {
        throw "Mic/Stereo Mix Permission Denied!";
      }

      final router = shelf_router.Router();
      router.get('/', (r) => Response.ok(webInterfaceHTML, headers: {'Content-Type': 'text/html'}));
      router.get('/stream', (r) => Response.ok(_audioStreamController!.stream, headers: {
        'Content-Type': 'audio/wav',
        'Transfer-Encoding': 'chunked',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
      }));

      _server = await shelf_io.serve(router.call, '0.0.0.0', 8080);
      setState(() {
        _isServerRunning = true;
        _statusMessage = "Broadcasting Live!";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.waves, size: 100, color: Color(0xFF38BDF8)),
            const SizedBox(height: 20),
            Text("Link: http://$_ipAddress:8080", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_statusMessage, style: TextStyle(color: _isServerRunning ? Colors.green : Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isServerRunning ? _stopServer : _startServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.red : Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: Text(_isServerRunning ? "STOP SERVER" : "START SERVER"),
            ),
          ],
        ),
      ),
    );
  }
}