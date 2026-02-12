import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tide_data.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final String locationId;
  final String locationName;

  const CalendarScreen({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _currentMonth;
  Map<String, List<TideEvent>> _monthTides = {};
  bool _loading = true;
  late AnimationController _gridAnimController;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _gridAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadMonth();
  }

  @override
  void dispose() {
    _gridAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final start = _currentMonth;
      final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final data = await api.getTidesRange(widget.locationId, start, end);
      setState(() {
        _monthTides = data;
        _loading = false;
      });
      _gridAnimController.forward(from: 0);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName),
        backgroundColor: const Color(0xFF0a1628),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Month navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white70, size: 28),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMonth = DateTime(
                            DateTime.now().year, DateTime.now().month);
                      });
                      _loadMonth();
                    },
                    child: Text(
                      '${months[_currentMonth.month - 1]} ${_currentMonth.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),

            // Day of week headers + grid, centered with max width
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator())
                            : GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity != null) {
                                    if (details.primaryVelocity! < -200) {
                                      _changeMonth(1);
                                    } else if (details.primaryVelocity! >
                                        200) {
                                      _changeMonth(-1);
                                    }
                                  }
                                },
                                child: _buildCalendarGrid(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final today = DateTime.now();
    final totalCells = daysInMonth + firstWeekday - 1;
    final rows = ((totalCells) / 7).ceil();
    final cellCount = rows * 7;

    return LayoutBuilder(builder: (context, constraints) {
    // Use actual available dimensions from the constrained layout
    final cellWidth = (constraints.maxWidth - 8) / 7;
    final cellHeight = (constraints.maxHeight - 6 * 3) / rows; // subtract spacing
    final aspectRatio = (cellWidth / cellHeight).clamp(0.35, 0.85);

    return AnimatedBuilder(
      animation: _gridAnimController,
      builder: (context, _) {
        return Opacity(
          opacity: _gridAnimController.value,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1 ||
                  index >= daysInMonth + firstWeekday - 1) {
                return const SizedBox();
              }

              final day = index - firstWeekday + 2;
              final date =
                  DateTime(_currentMonth.year, _currentMonth.month, day);
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final tides = _monthTides[dateStr] ?? [];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isPast =
                  date.isBefore(DateTime(today.year, today.month, today.day));

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => DayDetailScreen(
                          locationId: widget.locationId,
                          locationName: widget.locationName,
                          date: date,
                        ),
                        transitionsBuilder: (_, anim, __, child) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration:
                            const Duration(milliseconds: 300),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF1565C0).withValues(alpha: 0.25)
                          : const Color(0xFF132040)
                              .withValues(alpha: isPast ? 0.5 : 1.0),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: const Color(0xFF42A5F5), width: 1.5)
                          : null,
                    ),
                    child: Column(
                      children: [
                        // Day number
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF42A5F5)
                                : isPast
                                    ? Colors.white38
                                    : Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Tide events
                        ...tides
                            .take(4)
                            .map((t) => _buildTideMini(t, isPast)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    });
  }

  Widget _buildTideMini(TideEvent event, bool isPast) {
    final color = event.isHigh
        ? const Color(0xFF66BB6A)
        : const Color(0xFF42A5F5);
    final timeStr =
        '${event.dateTimeLocal.hour.toString().padLeft(2, '0')}:${event.dateTimeLocal.minute.toString().padLeft(2, '0')}';
    final heightStr = event.heightMetres.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isPast ? color.withValues(alpha: 0.3) : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              '$timeStr $heightStr',
              style: TextStyle(
                color: isPast
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
