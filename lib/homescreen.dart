import 'package:flutter/material.dart';
import 'package:flutter_application_1/detectionscreen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
              Color(0xFF1A237E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // Hero section
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        // App icon/logo
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.visibility_outlined,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Drowsiness Detection',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Trained using MRLEYE dataset',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Feature cards
                  _buildFeatureCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Real-time Monitoring',
                    description: 'Continuous webcam analysis using advanced computer vision',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildFeatureCard(
                    icon: Icons.warning_amber_outlined,
                    title: 'Instant Alerts',
                    description: 'Immediate notifications when drowsiness is detected',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                 /* _buildFeatureCard(
                    icon: Icons.psychology_outlined,
                    title: 'AI-Powered Analysis',
                    description: 'Machine learning algorithms for accurate detection',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
                    ),
                  ),
                  */
                  const SizedBox(height: 40),
                  
                  // Start button
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFAB40), Color(0xFFFF9800)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const DetectionScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: animation.drive(
                                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                                ),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Start Detection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Requirements info
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
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'System Requirements',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRequirement('Backend server running on localhost:5000'),
                        _buildRequirement('Camera access permission'),
                        _buildRequirement('Good lighting conditions'),
                        _buildRequirement('Clear face visibility'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
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
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.white.withOpacity(0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}