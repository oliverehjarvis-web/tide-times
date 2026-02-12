import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tide_data.dart';
import '../widgets/tide_chart.dart';
import '../widgets/tide_card.dart';
import '../widgets/sun_times_bar.dart';
import 'calendar_screen.dart';
import 'day_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _contentAnimController;
  late AnimationController _waveAnimController;
  Timer? _countdownTimer;
  final _locations = [
    Location(
        id: 'newquay',
        name: 'Newquay',
        latitude: 50.4167,
        longitude: -5.0833),
    Location(
        id: 'holywell',
        name: 'Holywell',
        latitude: 50.3930,
        longitude: -5.1480),
    Location(
        id: 'polzeath',
        name: 'Polzeath',
        latitude: 50.5720,
        longitude: -4.9190),
    Location(
        id: 'port_isaac',
        name: 'Port Isaac',
        latitude: 50.5930,
        longitude: -4.8290),
  ];

  DayTideData? _todayData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _locations.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentAnimController.dispose();
    _waveAnimController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final location = _locations[_tabController.index].id;
      final data = await api.getDayData(location, DateTime.now());
      setState(() {
        _todayData = data;
        _loading = false;
      });
      _contentAnimController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  TideEvent? _getNextTide() {
    if (_todayData == null) return null;
    final now = DateTime.now();
    for (final tide in _todayData!.tides) {
      if (tide.dateTimeLocal.isAfter(now)) return tide;
    }
    return null;
  }

  String _formatCountdown(TideEvent tide) {
    final diff = tide.dateTimeLocal.difference(DateTime.now());
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: const Color(0xFF0a1628),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tide Times',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Cornwall',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded,
                      color: Colors.white70),
                  tooltip: 'Calendar',
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => CalendarScreen(
                          locationId: _locations[_tabController.index].id,
                          locationName:
                              _locations[_tabController.index].name,
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
                ),
                const SizedBox(width: 4),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabs: _locations.map((l) => Tab(text: l.name)).toList(),
              ),
            ),
          ],
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load tide data',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_todayData == null) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final hPad = isWide ? 24.0 : 16.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                _staggeredItem(0, _buildDateHeader()),
                const SizedBox(height: 12),

                // Next tide countdown
                _staggeredItem(1, _buildNextTideHero()),
                const SizedBox(height: 16),

                // Tide chart
                _staggeredItem(2, _buildChartCard()),
                const SizedBox(height: 16),

                // Tide events
                _staggeredItem(3, _buildSectionLabel('Today\'s Tides')),
                const SizedBox(height: 8),
                ..._todayData!.tides.asMap().entries.map((entry) =>
                    _staggeredItem(
                      4 + entry.key,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TideCard(event: entry.value),
                      ),
                    )),
                const SizedBox(height: 12),

                // Sun times
                if (_todayData!.sunTimes != null) ...[
                  _staggeredItem(
                    4 + _todayData!.tides.length,
                    _buildSectionLabel('Daylight'),
                  ),
                  const SizedBox(height: 8),
                  _staggeredItem(
                    5 + _todayData!.tides.length,
                    SunTimesBar(sunTimes: _todayData!.sunTimes!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps a child in a staggered slide+fade animation
  Widget _staggeredItem(int index, Widget child) {
    final delay = (index * 0.08).clamp(0.0, 0.6);
    final end = (delay + 0.5).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _contentAnimController,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];

    return Text(
      '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 14,
      ),
    );
  }

  Widget _buildNextTideHero() {
    final nextTide = _getNextTide();
    if (nextTide == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1565C0).withValues(alpha: 0.25),
              const Color(0xFF0D47A1).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No more tides today',
          style: TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isHigh = nextTide.isHigh;
    final color =
        isHigh ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5);
    final label = isHigh ? 'Next High Tide' : 'Next Low Tide';
    final timeStr =
        '${nextTide.dateTimeLocal.hour.toString().padLeft(2, '0')}:${nextTide.dateTimeLocal.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _openDayDetail(DateTime.now()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Wave animation background
            AnimatedBuilder(
              animation: _waveAnimController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _WavePainter(
                    progress: _waveAnimController.value,
                    color: color,
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 110,
                  ),
                );
              },
            ),
            // Content overlay
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: color.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${nextTide.heightMetres.toStringAsFixed(1)}m',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'in ${_formatCountdown(nextTide)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return GestureDetector(
      onTap: () => _openDayDetail(DateTime.now()),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tide Height',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            color: const Color(0xFF42A5F5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF42A5F5), size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TideChart(
                hourlyLevels: _todayData!.hourlyLevels,
                tideEvents: _todayData!.tides,
                sunTimes: _todayData!.sunTimes,
                height: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  void _openDayDetail(DateTime date) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DayDetailScreen(
          locationId: _locations[_tabController.index].id,
          locationName: _locations[_tabController.index].name,
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
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Paints gentle animated waves at the bottom of the hero card
class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Wave 1
    final path1 = Path();
    path1.moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 1) {
      final y = size.height * 0.65 +
          math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) *
              8;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Wave 2 (offset)
    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 1) {
      final y = size.height * 0.75 +
          math.sin(
                  (x / size.width * 3 * math.pi) + (progress * 2 * math.pi) + 1.5) *
              6;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
