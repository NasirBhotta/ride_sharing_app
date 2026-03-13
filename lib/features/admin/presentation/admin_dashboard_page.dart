import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const _sectionGap = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          appBar:
              isDesktop
                  ? null
                  : AppBar(
                    title: const Text('Admin Dashboard'),
                    actions: [
                      IconButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        tooltip: 'Sign out',
                      ),
                    ],
                  ),
          drawer:
              isDesktop
                  ? null
                  : Drawer(
                    child: _AdminSidebar(
                      onTapSignOut: () => FirebaseAuth.instance.signOut(),
                    ),
                  ),
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 260,
                    child: _AdminSidebar(
                      onTapSignOut: () => FirebaseAuth.instance.signOut(),
                    ),
                  ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.surface,
                          theme.colorScheme.surface.withOpacity(0.96),
                          theme.colorScheme.surface.withOpacity(0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderBar(isTablet: isTablet),
                          const SizedBox(height: _sectionGap),
                          _MetricsGrid(isTablet: isTablet),
                          const SizedBox(height: _sectionGap),
                          _ChartsSection(isTablet: isTablet),
                          const SizedBox(height: _sectionGap),
                          _BottomSection(isTablet: isTablet),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final VoidCallback onTapSignOut;

  const _AdminSidebar({required this.onTapSignOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.dashboard_customize,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RideOps', style: theme.textTheme.titleMedium),
                      Text('Control Center', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SidebarItem(
            icon: Icons.analytics_outlined,
            label: 'Overview',
            isActive: true,
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.route_outlined,
            label: 'Rides',
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.people_alt_outlined,
            label: 'Customers',
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.directions_car_filled_outlined,
            label: 'Riders',
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.payments_outlined,
            label: 'Payments',
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.support_agent_outlined,
            label: 'Support',
            onTap: () {},
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: OutlinedButton.icon(
              onPressed: onTapSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.hintColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final bool isTablet;

  const _HeaderBar({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.9),
            theme.colorScheme.primary.withOpacity(0.7),
            theme.colorScheme.secondary.withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day, Admin',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ride operations at a glance',
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Monitor demand, dispatch health, and service quality across all regions.',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (isTablet)
            Container(
              width: 220,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispatch health',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '92% SLA',
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  LinearProgressIndicator(
                    value: 0.92,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final bool isTablet;

  const _MetricsGrid({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'Active rides',
        value: '128',
        delta: '+12%',
        icon: Icons.local_taxi,
        color: const Color(0xFF2DD4BF),
      ),
      _MetricData(
        label: 'Available riders',
        value: '342',
        delta: '+4%',
        icon: Icons.directions_car_filled,
        color: const Color(0xFF60A5FA),
      ),
      _MetricData(
        label: 'Avg. ETA',
        value: '5.4 min',
        delta: '-6%',
        icon: Icons.timer_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _MetricData(
        label: 'Revenue (24h)',
        value: 'PKR 1.92M',
        delta: '+18%',
        icon: Icons.payments_outlined,
        color: const Color(0xFF34D399),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isTablet ? 4 : 2;
        final childAspect = isTablet ? 2.1 : 1.6;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspect,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _MetricCard(metric: metric);
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: metric.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(metric.icon, color: metric.color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    metric.delta,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              metric.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(metric.value, style: theme.textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  final bool isTablet;

  const _ChartsSection({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ridesSeries = [
      const FlSpot(0, 110),
      const FlSpot(1, 140),
      const FlSpot(2, 120),
      const FlSpot(3, 150),
      const FlSpot(4, 170),
      const FlSpot(5, 160),
      const FlSpot(6, 190),
    ];

    final revenueBars = [
      _BarData('Lahore', 180),
      _BarData('Karachi', 220),
      _BarData('Islamabad', 150),
      _BarData('Peshawar', 110),
    ];

    final rideSplit = [
      _PieData('Car', 52, const Color(0xFF60A5FA)),
      _PieData('Bike', 28, const Color(0xFF34D399)),
      _PieData('Premium', 20, const Color(0xFFF59E0B)),
    ];

    final lineCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily rides', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Requests vs completions', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          final idx = value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              idx >= 0 && idx < labels.length
                                  ? labels[idx]
                                  : '',
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: ridesSeries,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.35),
                            theme.colorScheme.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final barCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by city', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Last 7 days (PKR)', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              idx >= 0 && idx < revenueBars.length
                                  ? revenueBars[idx].label
                                  : '',
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(revenueBars.length, (i) {
                    final data = revenueBars[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data.value,
                          width: 26,
                          borderRadius: BorderRadius.circular(8),
                          color: theme.colorScheme.secondary,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final pieCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ride mix', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Last 24 hours', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections:
                      rideSplit
                          .map(
                            (entry) => PieChartSectionData(
                              color: entry.color,
                              value: entry.value,
                              title: '${entry.value.toStringAsFixed(0)}%',
                              titleStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children:
                  rideSplit
                      .map(
                        (entry) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: entry.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(entry.label, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );

    if (isTablet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: lineCard),
          const SizedBox(width: 16),
          Expanded(child: barCard),
          const SizedBox(width: 16),
          SizedBox(width: 320, child: pieCard),
        ],
      );
    }

    return Column(
      children: [
        lineCard,
        const SizedBox(height: 16),
        barCard,
        const SizedBox(height: 16),
        pieCard,
      ],
    );
  }
}

class _BottomSection extends StatelessWidget {
  final bool isTablet;

  const _BottomSection({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final recentRides = [
      _RideRow('R-23904', 'Ayesha K', 'Bike', '3.2 km', 'Completed', 'PKR 540'),
      _RideRow(
        'R-23905',
        'Bilal A',
        'Car',
        '8.9 km',
        'In progress',
        'PKR 1,420',
      ),
      _RideRow(
        'R-23906',
        'Fatima Z',
        'Premium',
        '12.1 km',
        'Cancelled',
        'PKR 0',
      ),
      _RideRow('R-23907', 'Hassan S', 'Car', '5.4 km', 'Completed', 'PKR 860'),
    ];

    final topDrivers = [
      _DriverRow('Sara Imtiaz', 4.9, 92),
      _DriverRow('Ali Raza', 4.8, 88),
      _DriverRow('Noman Khan', 4.8, 85),
      _DriverRow('Kiran Malik', 4.7, 81),
    ];

    final ridesTable = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent rides', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ride')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Distance')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Fare')),
                ],
                rows:
                    recentRides
                        .map(
                          (ride) => DataRow(
                            cells: [
                              DataCell(Text(ride.id)),
                              DataCell(Text(ride.customer)),
                              DataCell(Text(ride.type)),
                              DataCell(Text(ride.distance)),
                              DataCell(_StatusPill(status: ride.status)),
                              DataCell(Text(ride.fare)),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );

    final driversCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top riders', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...topDrivers.map(
              (driver) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    driver.name.substring(0, 1),
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
                title: Text(driver.name),
                subtitle: Text('${driver.rides} rides this week'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(driver.rating.toStringAsFixed(1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isTablet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: ridesTable),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: driversCard),
        ],
      );
    }

    return Column(
      children: [ridesTable, const SizedBox(height: 16), driversCard],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status.toLowerCase()) {
      'completed' => const Color(0xFF34D399),
      'in progress' => theme.colorScheme.primary,
      'cancelled' => theme.colorScheme.error,
      _ => theme.colorScheme.secondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });
}

class _BarData {
  final String label;
  final double value;

  const _BarData(this.label, this.value);
}

class _PieData {
  final String label;
  final double value;
  final Color color;

  const _PieData(this.label, this.value, this.color);
}

class _RideRow {
  final String id;
  final String customer;
  final String type;
  final String distance;
  final String status;
  final String fare;

  const _RideRow(
    this.id,
    this.customer,
    this.type,
    this.distance,
    this.status,
    this.fare,
  );
}

class _DriverRow {
  final String name;
  final double rating;
  final int rides;

  const _DriverRow(this.name, this.rating, this.rides);
}
