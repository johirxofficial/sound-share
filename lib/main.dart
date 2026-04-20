import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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

  Future<void> _fetchNativeIP() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            if (mounted) setState(() => _ipAddress = addr.address);
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _ipAddress = "127.0.0.1 (Offline)");
    }
  }

  // 🔥 Magic Hack: Generate a WAV Header on the fly for raw PCM stream
  Uint8List _buildWavHeader(int sampleRate, int channels) {
    final byteRate = sampleRate * channels * 2;
    var header = ByteData(44);
    
    // RIFF chunk
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, 0xFFFFFFFF, Endian.little); // File size (Infinite for streaming)
    // WAVE fmt
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample
    // data chunk
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, 0xFFFFFFFF, Endian.little); // Data size (Infinite)
    
    return header.buffer.asUint8List();
  }

  // Stream generator that prepends the WAV header for every new connected browser
  Stream<List<int>> _streamWithWavHeader() async* {
    yield _buildWavHeader(44100, 2); // Send header first
    if (_audioStreamController != null) {
      await for (final chunk in _audioStreamController!.stream) {
        yield chunk; // Send live audio chunks
      }
    }
  }

  Future<void> _startServer() async {
    try {
      _audioStreamController = StreamController<List<int>>.broadcast();
      
      bool hasPerm = true;
      try {
         // Windows may not implement this properly, so we catch the error
         hasPerm = await _audioRecorder.hasPermission();
      } catch (e) {
         debugPrint("Permission check bypassed on Windows.");
      }

      if (hasPerm) {
        // 🔥 Reverted to pcm16bits to fix the Windows crash!
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
      } else {
        throw Exception("Microphone/Stereo Mix Permission Denied!");
      }

      final router = shelf_router.Router();
      
      router.get('/', (Request request) {
        return Response.ok(webInterfaceHTML, headers: {'Content-Type': 'text/html'});
      });

      router.get('/stream', (Request request) {
        if (_audioStreamController != null && !_audioStreamController!.isClosed) {
          return Response.ok(_streamWithWavHeader(), headers: {
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
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
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