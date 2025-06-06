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
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  List<dynamic> eyeResults = [];
  Map<String, dynamic>? mouthResult;
  String eyeStatus = "Initializing...";
  String yawnStatus = "No Face";
  bool alert = false;
  bool isLoading = true;
  html.VideoElement? videoElement;
  Timer? frameTimer;
  String? videoViewId;
  html.MediaStream? mediaStream;
  html.AudioElement? alertAudio;

  // Enhanced scoring system variables
  double alertnessScore = 100.0;
  static const double maxScore = 100.0;
  static const double minScore = 0.0;
  static const double alertThreshold = 30.5;
  static const double recoveryThreshold = 50.0;
  
  static const double eyesClosedDecrement = 9.0;
  static const double eyesOpenIncrement = 60.0;
  static const double yawnDecrement = 20.0;
  static const double yawnRecovery = 20.0;
  static const double blinkRecovery = 10.5;
  static const double combinedPenalty = 8.0;
  
  bool isAlertSoundPlaying = false;
  List<double> recentScores = [];
  static const int scoreHistoryLength = 5;
  
  // Yawn detection variables
  int consecutiveYawnFrames = 0;
  int consecutiveNormalFrames = 0;
  static const int yawnConfirmationFrames = 2;
  static const int normalConfirmationFrames = 3;
  
  // Yawn counting variables
  List<DateTime> yawnTimestamps = [];
  int yawnCount = 0;
  bool wasYawningPreviously = false;
  static const int yawnLimitPerMinute = 3;
  bool hasShownYawnWarning = false;
  bool hasShownZeroScoreWarning = false;

  // Correlation tracking
  bool wasYawning = false;
  bool wereEyesClosed = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      videoViewId = 'webcam-${DateTime.now().millisecondsSinceEpoch}';
      startWebcam();
    } else {
      setState(() {
        isLoading = false;
        eyeStatus = "Error: This app requires web platform";
      });
    }
  }

  Future<void> startWebcam() async {
    setState(() {
      isLoading = true;
      eyeStatus = "Requesting camera access...";
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
        eyeStatus = "Camera ready";
      });

      startFrameProcessing();
    } catch (e) {
      print('Webcam initialization error: $e');
      setState(() {
        isLoading = false;
        eyeStatus = "Error: Camera access denied or unavailable";
      });
    }
  }

  void startFrameProcessing() {
    if (frameTimer != null && frameTimer!.isActive) {
      return;
    }

    frameTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || videoElement == null) {
        timer.cancel();
        return;
      }

      try {
        final width = videoElement!.videoWidth;
        final height = videoElement!.videoHeight;
        if (width <= 0 || height <= 0) {
          return;
        }

        final canvas = html.CanvasElement()
          ..width = width
          ..height = height;

        final context = canvas.getContext('2d');
        if (context == null || context is! html.CanvasRenderingContext2D) {
          throw Exception('Failed to get 2D canvas context');
        }

        context.drawImage(videoElement!, 0, 0);

        final blob = await canvas.toBlob('image/jpeg', 0.8);
        if (blob != null) {
          await processFrame(blob);
        } else {
          throw Exception('Failed to create blob from canvas');
        }
      } catch (e, stackTrace) {
        print('Frame processing error: $e\n$stackTrace');
        setState(() {
          eyeStatus = 'Error processing frame: $e';
        });
      }
    });
  }

  Future<void> processFrame(html.Blob imageBlob) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/process_frame'),
      );

      final reader = html.FileReader();
      reader.readAsArrayBuffer(imageBlob);
      await reader.onLoad.first;
      
      final bytes = reader.result as List<int>;
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'frame',
          bytes,
          filename: 'frame.jpg',
        ),
      );

      final response = await request.send().timeout(const Duration(seconds: 5));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        setState(() {
          eyeResults = data['eyes'] ?? [];
          eyeStatus = data['eye_status'] ?? "No Eyes Detected";
          yawnStatus = data['yawn_status'] ?? "No Face";
          mouthResult = data['mouth'];
        });

        updateAlertnessScoreWithCorrelation(data);
        handleAlertState();
      } else {
        print('Backend error: ${response.statusCode} - $responseBody');
        setState(() {
          eyeStatus = "Backend error: ${response.statusCode}";
        });
      }
    } catch (e) {
      print('Request error: $e');
      setState(() {
        eyeStatus = "Connection error: Unable to reach backend";
      });
    }
  }

  void updateAlertnessScoreWithCorrelation(Map<String, dynamic> data) {
    double scoreChange = 0.0;
    bool eyesClosed = eyeStatus == "Closed Eyes";
    bool isYawning = yawnStatus == "Yawning";

    if (isYawning) {
      consecutiveYawnFrames++;
      consecutiveNormalFrames = 0;
    } else {
      consecutiveNormalFrames++;
      if (consecutiveNormalFrames >= normalConfirmationFrames) {
        consecutiveYawnFrames = 0;
      }
    }

    bool confirmedYawn = consecutiveYawnFrames >= yawnConfirmationFrames;

    if (wasYawningPreviously && !isYawning && confirmedYawn) {
      yawnCount++;
      yawnTimestamps.add(DateTime.now());
      print('Yawn counted. Total yawns: $yawnCount');
    }

    yawnTimestamps.removeWhere((timestamp) =>
        DateTime.now().difference(timestamp).inSeconds > 60);

    if (yawnTimestamps.length >= yawnLimitPerMinute && !hasShownYawnWarning) {
      showYawnWarningDialog();
      hasShownYawnWarning = true;
      Future.delayed(const Duration(minutes: 1), () {
        if (mounted) {
          setState(() {
            hasShownYawnWarning = false;
            yawnTimestamps.clear();
            yawnCount = 0;
          });
        }
      });
    }

    wasYawningPreviously = isYawning;

    if (eyesClosed) {
      scoreChange -= eyesClosedDecrement;
    } else if (eyeStatus == "Open Eyes") {
      scoreChange += eyesOpenIncrement;
      if (wereEyesClosed) {
        scoreChange += blinkRecovery;
      }
    }

    if (confirmedYawn) {
      scoreChange -= yawnDecrement;
      if (wasYawning && !isYawning) {
        scoreChange += yawnRecovery;
      }
    }

    if (eyesClosed && confirmedYawn) {
      scoreChange -= combinedPenalty;
      print('SEVERE DROWSINESS: Both eyes closed and yawning detected!');
    }

    if (eyeStatus == "Open Eyes" && !confirmedYawn) {
      if (wereEyesClosed || wasYawning) {
        scoreChange += 1.0;
      }
    }

    if (alertnessScore <= 4.0 && (eyesClosed || confirmedYawn)) {
      scoreChange -= 1.0;
    }

    alertnessScore = (alertnessScore + scoreChange).clamp(minScore, maxScore);
    
    if (alertnessScore == 0 && !hasShownZeroScoreWarning) {
      showZeroScoreWarningDialog();
      hasShownZeroScoreWarning = true;
      Future.delayed(const Duration(minutes: 1), () {
        if (mounted) {
          setState(() {
            hasShownZeroScoreWarning = false;
          });
        }
      });
    }

    recentScores.add(alertnessScore);
    if (recentScores.length > scoreHistoryLength) {
      recentScores.removeAt(0);
    }

    if (recentScores.length >= 3) {
      double smoothedScore = recentScores.reduce((a, b) => a + b) / recentScores.length;
      alertnessScore = smoothedScore;
    }

    wasYawning = confirmedYawn;
    wereEyesClosed = eyesClosed;

    print('Alertness Score: ${alertnessScore.toStringAsFixed(1)} | Eyes: $eyeStatus | Yawn: ${confirmedYawn ? "CONFIRMED" : yawnStatus} | Change: ${scoreChange.toStringAsFixed(1)}');
  }

  void showZeroScoreWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF0f3460),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Lottie.asset(
                    'assets/animations/sleep.json',
                    fit: BoxFit.contain,
                    width: 180,
                    height: 180,
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Critical Alert!',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You are extremely drowsy and unfit to drive. Please take a break immediately!',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        frameTimer?.cancel();
                        Future.delayed(const Duration(minutes: 5), () {
                          if (mounted) startFrameProcessing();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Snooze (5 min)',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showYawnWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB74D),
                  Color(0xFFe65100),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Lottie.asset(
                    'assets/animations/yawn.json',
                    fit: BoxFit.contain,
                    width: 180,
                    height: 180,
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Frequent Yawning Alert!',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You have yawned 3 times in a minute. Take a break to stay alert!',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        frameTimer?.cancel();
                        Future.delayed(const Duration(minutes: 5), () {
                          if (mounted) startFrameProcessing();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Snooze (5 min)',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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

  String getAlertnessStatus() {
    bool eyesClosed = eyeStatus == "Closed Eyes";
    bool confirmedYawn = consecutiveYawnFrames >= yawnConfirmationFrames;
    
    if (alertnessScore > 70) {
      return "Alert and Focused";
    } else if (alertnessScore > 50) {
      if (confirmedYawn || eyesClosed) {
        return "Mild Drowsiness - Stay Alert";
      }
      return "Slightly Drowsy";
    } else if (alertnessScore > 30) {
      if (eyesClosed && confirmedYawn) {
        return "SEVERE DROWSINESS - Multiple Signs!";
      } else if (eyesClosed) {
        return "Drowsy - Eyes Closing";
      } else if (confirmedYawn) {
        return "Drowsy - Yawning Detected";
      }
      return "Moderately Drowsy";
    } else {
      return "CRITICAL - IMMEDIATE ATTENTION NEEDED!";
    }
  }

  Color getScoreColor() {
    if (alertnessScore > 70) {
      return Colors.green;
    } else if (alertnessScore > 50) {
      return Colors.yellow;
    } else if (alertnessScore > 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  List<dynamic> getCombinedResults() {
    List<dynamic> combined = [];
    
    for (var eye in eyeResults) {
      combined.add({
        'box': eye['box'],
        'status': eye['status'],
        'type': 'eye',
        'confidence': 0.9,
      });
    }
    
    if (mouthResult != null) {
      combined.add({
        'box': mouthResult!['box'],
        'status': mouthResult!['status'],
        'type': 'mouth',
        'confidence': mouthResult!['confidence'] ?? 0.8,
      });
    }
    
    return combined;
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
    final combinedResults = getCombinedResults();
    
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
                              ' / 100',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: alertnessScore / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: getScoreColor(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (eyeStatus == "Closed Eyes")
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Eyes Closed',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            if (consecutiveYawnFrames >= yawnConfirmationFrames) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Yawning',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          VideoFeedWidget(
                            videoViewId: videoViewId,
                            isLoading: isLoading,
                            videoElement: videoElement,
                          ),
                          if (!isLoading)
                            CustomPaint(
                              size: const Size(640, 480),
                              painter: BoundingBoxPainter(combinedResults),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: StatusCard(
                      status: getAlertnessStatus(),
                      alert: alert,
                      detectionCount: combinedResults.length,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                eyeStatus.contains('Closed')
                                    ? Color(0xFFFF7043)
                                    : Color(0xFF4FC3F7),
                                eyeStatus.contains('Closed')
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
                                  eyeStatus.contains('Closed')
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
                                      eyeStatus,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Eyes: ${eyeResults.length} detected',
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                yawnStatus == 'Yawning'
                                    ? Color(0xFFFFB74D)
                                    : Color(0xFF81C784),
                                yawnStatus == 'Yawning'
                                    ? Color(0xFFFF9800)
                                    : Color(0xFF4CAF50),
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
                                  yawnStatus == 'Yawning'
                                      ? Icons.sentiment_very_dissatisfied_rounded
                                      : Icons.sentiment_satisfied_rounded,
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
                                      yawnStatus,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Yawns this minute: $yawnCount',
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
                      ),
                    ],
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