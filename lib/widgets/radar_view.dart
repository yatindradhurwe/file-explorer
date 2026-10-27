import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/nearby_device.dart';

class RadarView extends StatefulWidget {
  final List<NearbyDevice> devices;
  final ValueChanged<NearbyDevice> onDeviceSelected;
  final String centerDeviceName;

  const RadarView({
    super.key,
    required this.devices,
    required this.onDeviceSelected,
    required this.centerDeviceName,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final radius = size / 2 - 40;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Concentric Animated Ripple Waves
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _RadarWavePainter(
                    animationValue: _controller.value,
                    primaryColor: theme.colorScheme.primary,
                    isDark: isDark,
                  ),
                );
              },
            ),

            // Center Device (Self)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(120),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.centerDeviceName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Visible to nearby',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),

            // Discovered Nearby Device Bubbles (AirDrop style)
            ..._buildDeviceBubbles(center, radius),
          ],
        );
      },
    );
  }

  List<Widget> _buildDeviceBubbles(Offset center, double radius) {
    final List<Widget> widgets = [];
    final count = widget.devices.length;
    if (count == 0) return widgets;

    // Distribute devices in an arc around the center
    final angleStep = (2 * math.pi) / math.max(count, 3);

    for (int i = 0; i < count; i++) {
      final device = widget.devices[i];
      final angle = (i * angleStep) - (math.pi / 2);
      final r = radius * 0.75;
      final x = center.dx + r * math.cos(angle) - 40;
      final y = center.dy + r * math.sin(angle) - 45;

      widgets.add(
        Positioned(
          left: x,
          top: y,
          child: InkWell(
            onTap: () => widget.onDeviceSelected(device),
            borderRadius: BorderRadius.circular(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    device.icon,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

class _RadarWavePainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final bool isDark;

  _RadarWavePainter({
    required this.animationValue,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 10;

    // Draw 3 static faint guide rings
    final staticPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxRadius * 0.35, staticPaint);
    canvas.drawCircle(center, maxRadius * 0.65, staticPaint);
    canvas.drawCircle(center, maxRadius * 0.95, staticPaint);

    // Draw pulsating ripple waves
    for (int i = 0; i < 3; i++) {
      final waveProgress = (animationValue + (i / 3.0)) % 1.0;
      final waveRadius = maxRadius * waveProgress;
      final alpha = ((1.0 - waveProgress) * 90).toInt();

      final wavePaint = Paint()
        ..color = primaryColor.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
