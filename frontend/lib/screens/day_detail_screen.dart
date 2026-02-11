import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tide_data.dart';
import '../widgets/tide_chart.dart';
import '../widgets/tide_card.dart';
import '../widgets/sun_times_bar.dart';

class DayDetailScreen extends StatefulWidget {
  final String locationId;
  final String locationName;
  final DateTime date;

  const DayDetailScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.date,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  DayTideData? _data;
  bool _loading = true;
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getDayData(widget.locationId, _currentDate);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _previousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    });
    _loadData();
  }

  void _nextDay() {
    setState(() {
      _currentDate = _currentDate.add(const Duration(days: 1));
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Date navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousDay,
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                ),
                Column(
                  children: [
                    Text(
                      '${days[_currentDate.weekday - 1]}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${_currentDate.day} ${months[_currentDate.month - 1]} ${_currentDate.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _nextDay,
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data == null
                    ? const Center(
                        child: Text('No data available',
                            style: TextStyle(color: Colors.white54)))
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full tide chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tide Height',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TideChart(
                    hourlyLevels: _data!.hourlyLevels,
                    tideEvents: _data!.tides,
                    sunTimes: _data!.sunTimes,
                    height: 260,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Tide events
          Text(
            'Tides',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ..._data!.tides.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TideCard(event: event),
              )),

          const SizedBox(height: 16),

          // Sun times
          if (_data!.sunTimes != null) ...[
            Text(
              'Daylight',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SunTimesBar(sunTimes: _data!.sunTimes!),
          ],

          const SizedBox(height: 16),

          // Hourly levels table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hourly Water Levels',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._data!.hourlyLevels.map((level) {
                    final timeStr =
                        '${level.dateTimeUtc.hour.toString().padLeft(2, '0')}:00';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildLevelBar(level.heightMetres),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${level.heightMetres.toStringAsFixed(1)}m',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLevelBar(double height) {
    // Normalize to 0-8m range
    final fraction = (height / 8.0).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1565C0),
                      const Color(0xFF42A5F5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
