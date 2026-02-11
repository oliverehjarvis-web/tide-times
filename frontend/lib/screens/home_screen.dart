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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _locations = [
    Location(id: 'newquay', name: 'Newquay', latitude: 50.4167, longitude: -5.0833),
    Location(id: 'holywell', name: 'Holywell', latitude: 50.3930, longitude: -5.1480),
    Location(id: 'polzeath', name: 'Polzeath', latitude: 50.5720, longitude: -4.9190),
    Location(id: 'port_isaac', name: 'Port Isaac', latitude: 50.5930, longitude: -4.8290),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tide Times',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Cornwall',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white70),
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
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: _locations.map((l) => Tab(text: l.name)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load tide data',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_todayData == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            _buildDateHeader(),
            const SizedBox(height: 16),

            // Tide chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        GestureDetector(
                          onTap: () => _openDayDetail(DateTime.now()),
                          child: Text(
                            'View Details',
                            style: TextStyle(
                              color: const Color(0xFF42A5F5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TideChart(
                      hourlyLevels: _todayData!.hourlyLevels,
                      tideEvents: _todayData!.tides,
                      sunTimes: _todayData!.sunTimes,
                      height: 220,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tide events
            Text(
              'Today\'s Tides',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _todayData!.tides
                  .map((event) => TideCard(event: event))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Sun times
            if (_todayData!.sunTimes != null) ...[
              Text(
                'Daylight',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SunTimesBar(sunTimes: _todayData!.sunTimes!),
            ],

            const SizedBox(height: 24),
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
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Text(
      '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontWeight: FontWeight.w400,
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
