import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String status;
  final bool alert;
  final int detectionCount;

  const StatusCard({
    Key? key,
    required this.status,
    required this.alert,
    required this.detectionCount,
  }) : super(key: key);

  Color _getStatusColor() {
    if (alert) return Colors.red;
    if (status.contains('Error')) return Colors.red;
    if (status.contains('Closed Eyes')) return Colors.orange;
    if (status.contains('Connection error')) return Colors.red;
    return Colors.green;
  }

  IconData _getStatusIcon() {
    if (alert) return Icons.warning;
    if (status.contains('Error')) return Icons.error;
    if (status.contains('Closed Eyes')) return Icons.visibility_off;
    if (status.contains('Connection error')) return Icons.wifi_off;
    if (status.contains('ready')) return Icons.check_circle;
    return Icons.visibility;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getStatusColor(),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Status',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Detection stats
          if (detectionCount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Objects Detected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      detectionCount.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Alert indicator
          if (alert) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ALERT: Drowsiness Detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Status indicators
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator(
                'Camera',
                status.contains('ready') || detectionCount > 0,
                Icons.camera_alt,
              ),
              _buildStatusIndicator(
                'Backend',
                !status.contains('Connection error') && !status.contains('Backend error'),
                Icons.dns,
              ),
              _buildStatusIndicator(
                'Processing',
                detectionCount > 0 || status.contains('ready'),
                Icons.psychology,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive 
                ? Colors.green.withOpacity(0.2) 
                : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.green : Colors.grey,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive 
                ? Colors.white.withOpacity(0.9) 
                : Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}