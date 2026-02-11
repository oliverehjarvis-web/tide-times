import 'package:flutter/material.dart';
import '../models/tide_data.dart';

class TideCard extends StatelessWidget {
  final TideEvent event;

  const TideCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isHigh = event.isHigh;
    final color = isHigh ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5);
    final icon = isHigh ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label = isHigh ? 'HIGH' : 'LOW';
    final timeStr =
        '${event.dateTimeLocal.hour.toString().padLeft(2, '0')}:${event.dateTimeLocal.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Text(
            '${event.heightMetres.toStringAsFixed(1)}m',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
