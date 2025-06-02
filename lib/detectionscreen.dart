import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/bounding.dart';
import 'package:flutter_application_1/statuscard.dart';
import 'package:flutter_application_1/widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart' show kIsWeb;


class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with TickerProviderStateMixin {
  List<dynamic> detectionResults = [];
  String status = "Initializing...";
  bool alert = false;
  bool isLoading = true;
  html.VideoElement? videoElement;
  Timer? frameTimer;
  String? videoViewId;
  html.MediaStream? mediaStream;
  
  // Eye closure tracking variables
  DateTime? eyesClosedStartTime;
  static const Duration eyesClosedThreshold = Duration(seconds: 5);
  bool hasPlayedAlert = false;
  
  late AnimationController _alertAnimationController;
  late Animation<double> _alertAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _alertAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _alertAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _alertAnimationController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (kIsWeb) {
      videoViewId = 'webcam-${DateTime.now().millisecondsSinceEpoch}';
      startWebcam();
    } else {
      setState(() {
        isLoading = false;
        status = "Error: This app requires web platform";
      });
    }
  }

  Future<void> startWebcam() async {
    setState(() {
      isLoading = true;
      status = "Requesting camera access...";
    });

    try {
      mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'width': 640, 'height': 480}
      });

      videoElement = html.VideoElement()
        ..id = videoViewId!
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      videoElement!.srcObject = mediaStream;

      ui_web.platformViewRegistry.registerViewFactory(
        videoViewId!,
        (int viewId) => videoElement!,
      );

      await videoElement!.onLoadedMetadata.first;
      
      setState(() {
        isLoading = false;
        status = "Camera ready";
      });

      startFrameProcessing();

    } catch (e) {
      print('Webcam initialization error: $e');
      setState(() {
        isLoading = false;
        status = "Error: Camera access denied or unavailable";
      });
    }
  }

  void startFrameProcessing() {
    frameTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || videoElement == null) return;

      try {
        if (videoElement!.videoWidth == 0 || videoElement!.videoHeight == 0) {
          return;
        }

        final canvas = html.CanvasElement(
          width: videoElement!.videoWidth,
          height: videoElement!.videoHeight,
        );
        
        final context = canvas.getContext('2d') as html.CanvasRenderingContext2D;
        context.drawImage(videoElement!, 0, 0);
        
        final imageData = canvas.toDataUrl('image/jpeg', 0.8);
        await processFrame(imageData);

      } catch (e) {
        print('Frame processing error: $e');
        setState(() {
          status = "Error processing frame: $e";
        });
      }
    });
  }

  Future<void> processFrame(String imageData) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/detect'),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({'frame': imageData}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAlert = data['alert'] ?? false;
        
        setState(() {
          detectionResults = data['objects'] ?? [];
          status = data['status'] ?? "No detection";
        });

        // Handle eye closure timing logic
        if (newAlert) {
          // Eyes are closed
          if (eyesClosedStartTime == null) {
            eyesClosedStartTime = DateTime.now();
            hasPlayedAlert = false;
          } else {
            // Check if eyes have been closed for the threshold duration
            final closedDuration = DateTime.now().difference(eyesClosedStartTime!);
            if (closedDuration >= eyesClosedThreshold && !hasPlayedAlert) {
              playAlertSound();
              hasPlayedAlert = true;
            }
          }
        } else {
          // Eyes are open - reset the timer
          eyesClosedStartTime = null;
          hasPlayedAlert = false;
        }

        // Handle alert state changes with animation (for visual feedback only)
        if (newAlert != alert) {
          setState(() {
            alert = newAlert;
          });
          
          if (alert) {
            _alertAnimationController.forward();
            _pulseController.repeat(reverse: true);
          } else {
            _alertAnimationController.reverse();
            _pulseController.stop();
          }
        }
      } else {
        print('Backend error: ${response.statusCode} - ${response.body}');
        setState(() {
          status = "Backend error: ${response.statusCode}";
        });
      }
    } catch (e) {
      print('Request error: $e');
      setState(() {
        status = "Connection error: Unable to reach backend";
      });
    }
  }

  void playAlertSound() {
    try {
      final audio = html.AudioElement()
        ..src = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBziR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmEXBjas6Gmd'
        ..loop = false;
      
      audio.play().catchError((e) {
        print('Error playing alert sound: $e');
      });
    } catch (e) {
      print('Alert sound creation error: $e');
    }
  }

  @override
  void dispose() {
    frameTimer?.cancel();
    _alertAnimationController.dispose();
    _pulseController.dispose();
    
    if (mediaStream != null) {
      mediaStream!.getTracks().forEach((track) {
        track.stop();
      });
    }
    
    videoElement?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Drowsiness Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Video feed container
                Container(
                  width: 640,
                  height: 480,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Video feed
                        VideoFeedWidget(
                          videoViewId: videoViewId,
                          isLoading: isLoading,
                          videoElement: videoElement,
                        ),
                        
                        // Bounding boxes overlay
                        if (!isLoading)
                          CustomPaint(
                            size: const Size(640, 480),
                            painter: BoundingBoxPainter(detectionResults),
                          ),
                        
                        // Animated alert border (subtle visual feedback)
                        if (alert)
                          AnimatedBuilder(
                            animation: _alertAnimation,
                            builder: (context, child) {
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.red.withOpacity(_alertAnimation.value * 0.8),
                                    width: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status card with eye closure timing info
                StatusCard(
                  status: _getStatusWithTiming(),
                  alert: alert,
                  detectionCount: detectionResults.length,
                ),
                
                const SizedBox(height: 24),
                
                // Detection stats
                if (detectionResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Detection Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...detectionResults.map((result) {
                          final objectStatus = result['status'] ?? 'Unknown';
                          final confidence = result['confidence'] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  objectStatus,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  '${(confidence * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusWithTiming() {
    if (eyesClosedStartTime != null) {
      final closedDuration = DateTime.now().difference(eyesClosedStartTime!);
      final remainingSeconds = (eyesClosedThreshold.inSeconds - closedDuration.inSeconds).clamp(0, eyesClosedThreshold.inSeconds);
      
      if (remainingSeconds > 0) {
        return "Eyes closed for ${closedDuration.inSeconds}s (Alert in ${remainingSeconds}s)";
      } else {
        return "DROWSINESS DETECTED - Stay Alert!";
      }
    }
    return status;
  }
}