

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

class _DetectionScreenState extends State<DetectionScreen> {
  List<dynamic> detectionResults = [];
  String status = "Initializing...";
  bool alert = false;
  bool isLoading = true;
  html.VideoElement? videoElement;
  Timer? frameTimer;
  String? videoViewId;
  html.MediaStream? mediaStream;
  html.AudioElement? alertAudio;

  // Scoring system variables
  double alertnessScore = 10.0; // Start at maximum alertness
  static const double maxScore = 10.0;
  static const double minScore = 0.0;
  static const double alertThreshold = 3.0; // Alert when score drops below this
  static const double recoveryThreshold = 5.0; // Stop alert when score goes above this
  
  // Score adjustment rates
  static const double eyesClosedDecrement = 8.0; // Points lost per frame when eyes closed
  static const double eyesOpenIncrement = 4.0; // Points gained per frame when eyes open
  static const double yawnDecrement = 5.0; // Additional points lost for yawning
  static const double blinkRecovery = 2.0; // Small recovery for normal blinking
  
  bool isAlertSoundPlaying = false;
  List<double> recentScores = []; // Track recent scores for smoothing
  static const int scoreHistoryLength = 5;

  @override
  void initState() {
    super.initState();

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
        final detectionAlert = data['alert'] ?? false;

        setState(() {
          detectionResults = data['objects'] ?? [];
          status = data['status'] ?? "No detection";
        });

        // Update alertness score based on detection results
        updateAlertnessScore(detectionAlert, data);
        
        // Handle alert state based on score
        handleAlertState();

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

  void updateAlertnessScore(bool eyesClosed, Map<String, dynamic> data) {
    double scoreChange = 0.0;

    if (eyesClosed) {
      // Eyes are closed - decrease score
      scoreChange = -eyesClosedDecrement;
      
      // Check for additional drowsiness indicators
      if (data.containsKey('yawn_detected') && data['yawn_detected'] == true) {
        scoreChange -= yawnDecrement;
      }
    } else {
      // Eyes are open - increase score
      scoreChange = eyesOpenIncrement;
      
      // Check if it's a normal blink pattern (eyes were closed briefly)
      if (recentScores.isNotEmpty && recentScores.last < alertnessScore) {
        scoreChange += blinkRecovery;
      }
    }

    // Apply score change with bounds checking
    alertnessScore = (alertnessScore + scoreChange).clamp(minScore, maxScore);
    
    // Add to recent scores for smoothing and analysis
    recentScores.add(alertnessScore);
    if (recentScores.length > scoreHistoryLength) {
      recentScores.removeAt(0);
    }

    // Apply smoothing to reduce noise
    if (recentScores.length >= 3) {
      alertnessScore = recentScores.reduce((a, b) => a + b) / recentScores.length;
    }

    print('Alertness Score: ${alertnessScore.toStringAsFixed(1)} (Change: ${scoreChange.toStringAsFixed(1)})');
  }

  void handleAlertState() {
    bool shouldAlert = alertnessScore <= alertThreshold;
    bool shouldStopAlert = alertnessScore >= recoveryThreshold;

    if (shouldAlert && !isAlertSoundPlaying) {
      startAlertSound();
      setState(() {
        alert = true;
      });
    } else if (shouldStopAlert && isAlertSoundPlaying) {
      stopAlertSound();
      setState(() {
        alert = false;
      });
    }
  }

  void startAlertSound() {
    try {
      if (alertAudio == null) {
        alertAudio = html.AudioElement()
          ..src = 'assets/audio/sound.mp3'
          ..loop = true;
      }

      alertAudio!.play().catchError((e) {
        print('Error playing alert sound: $e');
      });
      isAlertSoundPlaying = true;
    } catch (e) {
      print('Alert sound creation error: $e');
    }
  }

  void stopAlertSound() {
    try {
      if (alertAudio != null && isAlertSoundPlaying) {
        alertAudio!.pause();
        alertAudio!.currentTime = 0;
        isAlertSoundPlaying = false;
      }
    } catch (e) {
      print('Error stopping alert sound: $e');
    }
  }

  String getAlertnesStatus() {
    if (alertnessScore > 7) {
      return "Alert and Focused";
    } else if (alertnessScore > 5) {
      return "Slightly Drowsy";
    } else if (alertnessScore > 3) {
      return "Moderately Drowsy";
    } else {
      return "DROWSINESS DETECTED - Stay Alert!";
    }
  }

  Color getScoreColor() {
    if (alertnessScore > 7) {
      return Colors.green;
    } else if (alertnessScore > 5) {
      return Colors.yellow;
    } else if (alertnessScore > 3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    frameTimer?.cancel();
    stopAlertSound();
    alertAudio?.remove();
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0a0a0a),
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'Drowsiness Detection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Alertness Score Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [
                          getScoreColor().withOpacity(0.2),
                          getScoreColor().withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(color: getScoreColor().withOpacity(0.5), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Alertness Score',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${alertnessScore.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: getScoreColor(),
                              ),
                            ),
                            Text(
                              ' / 10',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Score bar
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: alertnessScore / 10,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: getScoreColor(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Video feed container
                  Container(
                    width: 640,
                    height: 480,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: alert
                          ? Border.all(color: Colors.red.withOpacity(0.8), width: 4)
                          : Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: StatusCard(
                      status: getAlertnesStatus(),
                      alert: alert,
                      detectionCount: detectionResults.length,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Detection details in grid layout
                  if (detectionResults.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: detectionResults.asMap().entries.map((entry) {
                        final index = entry.key;
                        final result = entry.value;
                        final objectStatus = result['status'] ?? 'Unknown';
                        final confidence = result['confidence'] ?? 0.0;

                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              left: index == 0 ? 0 : 10,
                              right: index == detectionResults.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  objectStatus.contains('Closed')
                                      ? Color(0xFFFF7043)
                                      : Color(0xFF4FC3F7),
                                  objectStatus.contains('Closed')
                                      ? Color(0xFFE64A19)
                                      : Color(0xFF0288D1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    objectStatus.contains('Closed')
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        objectStatus,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}