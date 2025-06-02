import 'package:flutter/material.dart';
import 'dart:html' as html;

class VideoFeedWidget extends StatelessWidget {
  final String? videoViewId;
  final bool isLoading;
  final html.VideoElement? videoElement;

  const VideoFeedWidget({
    Key? key,
    required this.videoViewId,
    required this.isLoading,
    required this.videoElement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 640,
      height: 480,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Video stream
          if (videoElement != null && !isLoading && videoViewId != null)
            SizedBox(
              width: 640,
              height: 480,
              child: HtmlElementView(
                viewType: videoViewId!,
              ),
            ),
          
          // Loading state
          if (isLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initializing Camera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please allow camera access',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Camera frame overlay
          if (!isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
            ),
          
          // Corner indicators
          if (!isLoading) ...[
            // Top-left corner
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                    left: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                  ),
                ),
              ),
            ),
            // Top-right corner
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                    right: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                  ),
                ),
              ),
            ),
            // Bottom-left corner
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                    left: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                  ),
                ),
              ),
            ),
            // Bottom-right corner
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                    right: BorderSide(color: Colors.white.withOpacity(0.8), width: 3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}