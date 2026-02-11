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
  bool _hourlyExpanded = false;

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

  void _changeDay(int delta) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: delta));
      _hourlyExpanded = false;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeDay(-1),
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white70, size: 28),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          days[_currentDate.weekday - 1],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                  ),
                  IconButton(
                    onPressed: () => _changeDay(1),
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),

            // Swipeable content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? const Center(
                          child: Text('No data available',
                              style: TextStyle(color: Colors.white54)))
                      : GestureDetector(
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity != null) {
                              if (details.primaryVelocity! < -200) {
                                _changeDay(1);
                              } else if (details.primaryVelocity! > 200) {
                                _changeDay(-1);
                              }
                            }
                          },
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tide chart
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Tide Height',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TideChart(
                    hourlyLevels: _data!.hourlyLevels,
                    tideEvents: _data!.tides,
                    sunTimes: _data!.sunTimes,
                    height: 220,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tide events
          _buildSectionLabel('Tides'),
          const SizedBox(height: 8),
          ..._data!.tides.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TideCard(event: event),
              )),

          const SizedBox(height: 12),

          // Sun times
          if (_data!.sunTimes != null) ...[
            _buildSectionLabel('Daylight'),
            const SizedBox(height: 8),
            SunTimesBar(sunTimes: _data!.sunTimes!),
            const SizedBox(height: 12),
          ],

          // Collapsible hourly levels
          if (_data!.hourlyLevels.isNotEmpty) _buildHourlySection(),
        ],
      ),
    );
  }

  Widget _buildHourlySection() {
    return Card(
      child: Column(
        children: [
          // Header / toggle
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _hourlyExpanded = !_hourlyExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hourly Water Levels',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    _hourlyExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white38,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: _data!.hourlyLevels.map((level) {
                  final timeStr =
                      '${level.dateTimeLocal.hour.toString().padLeft(2, '0')}:00';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildLevelBar(level.heightMetres),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${level.heightMetres.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _hourlyExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
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

  Widget _buildLevelBar(double height) {
    final fraction = (height / 8.0).clamp(0.0, 1.0);
    return Stack(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    );
  }
}
