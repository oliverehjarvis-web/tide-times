import 'package:flutter/material.dart';
import '../models/tide_data.dart';

class SunTimesBar extends StatelessWidget {
  final SunTimes sunTimes;

  const SunTimesBar({super.key, required this.sunTimes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a237e).withValues(alpha: 0.3),
            const Color(0xFFFF8F00).withValues(alpha: 0.15),
            const Color(0xFFFF6D00).withValues(alpha: 0.15),
            const Color(0xFF1a237e).withValues(alpha: 0.3),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SunItem(
            icon: Icons.wb_sunny_rounded,
            label: 'Sunrise',
            time: sunTimes.sunrise,
            color: const Color(0xFFFFB74D),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _SunItem(
            icon: Icons.access_time_rounded,
            label: 'Daylight',
            time: '${sunTimes.dayLengthHours.toStringAsFixed(1)}h',
            color: Colors.white70,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _SunItem(
            icon: Icons.nightlight_round,
            label: 'Sunset',
            time: sunTimes.sunset,
            color: const Color(0xFFFF8A65),
          ),
        ],
      ),
    );
  }
}

class _SunItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _SunItem({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
