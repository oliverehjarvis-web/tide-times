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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                      MaterialPageRoute(
                        builder: (_) => CalendarScreen(
                          locationId: _locations[_tabController.index].id,
                          locationName: _locations[_tabController.index].name,
                        ),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            _buildDateHeader(),
            const SizedBox(height: 12),

            // Next tide countdown
            _buildNextTideHero(),
            const SizedBox(height: 16),

            // Tide chart
            _buildChartCard(),
            const SizedBox(height: 16),

            // Tide events
            _buildSectionLabel('Today\'s Tides'),
            const SizedBox(height: 8),
            ..._todayData!.tides.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TideCard(event: event),
                )),
            const SizedBox(height: 12),

            // Sun times
            if (_todayData!.sunTimes != null) ...[
              _buildSectionLabel('Daylight'),
              const SizedBox(height: 8),
              SunTimesBar(sunTimes: _todayData!.sunTimes!),
            ],
          ],
        ),
      ),
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
    final color = isHigh ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5);
    final label = isHigh ? 'Next High Tide' : 'Next Low Tide';
    final timeStr =
        '${nextTide.dateTimeLocal.hour.toString().padLeft(2, '0')}:${nextTide.dateTimeLocal.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _openDayDetail(DateTime.now()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(
          locationId: _locations[_tabController.index].id,
          locationName: _locations[_tabController.index].name,
          date: date,
        ),
      ),
    );
  }
}
