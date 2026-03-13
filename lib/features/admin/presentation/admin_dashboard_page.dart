import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_app/features/admin/data/admin_repository.dart';
import 'package:ride_sharing_app/features/auth/domain/user.dart';
import 'package:ride_sharing_app/features/rides/domain/ride_request.dart';
import 'package:ride_sharing_app/features/rides/domain/vehicle_type.dart';
import 'package:ride_sharing_app/features/role/domain/user_role.dart';


enum AdminSection { overview, rides, customers, riders, payments, support }

extension AdminSectionX on AdminSection {
  String get label => switch (this) {
        AdminSection.overview => 'Overview',
        AdminSection.rides => 'Rides',
        AdminSection.customers => 'Customers',
        AdminSection.riders => 'Riders',
        AdminSection.payments => 'Payments',
        AdminSection.support => 'Support',
      };
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AdminRepository _adminRepository;
  AdminSection _selectedSection = AdminSection.overview;

  @override
  void initState() {
    super.initState();
    _adminRepository = AdminRepository();
  }

  static const _sectionGap = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          appBar: isDesktop
              ? null
              : AppBar(
                  title: Text(_sectionTitle),
                  actions: [
                    IconButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sign out',
                    ),
                  ],
                ),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: _AdminSidebar(
                    selectedSection: _selectedSection,
                    onSelect: (section) {
                      setState(() => _selectedSection = section);
                      Navigator.pop(context);
                    },
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
                      selectedSection: _selectedSection,
                      onSelect: (section) =>
                          setState(() => _selectedSection = section),
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
                      child: _buildSectionContent(isTablet),
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

  String get _sectionTitle => _selectedSection.label;

  Widget _buildSectionContent(bool isTablet) {
    return switch (_selectedSection) {
      AdminSection.overview => _buildOverviewSection(isTablet),
      AdminSection.rides => _buildRidesSection(isTablet),
      AdminSection.customers => _buildUsersSection(UserRole.customer, isTablet),
      AdminSection.riders => _buildUsersSection(UserRole.rider, isTablet),
      AdminSection.payments => _buildPaymentsSection(isTablet),
      AdminSection.support => _buildPlaceholderSection(
          title: 'Support',
          message:
              'Support tickets are not configured yet. Add a support collection to enable this view.',
        ),
    };
  }

  Widget _buildOverviewSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderBar(isTablet: isTablet),
        const SizedBox(height: _sectionGap),
        StreamBuilder<int>(
          stream: _adminRepository.getActiveRidesCount(),
          builder: (context, activeRidesSnapshot) {
            return StreamBuilder<int>(
              stream: _adminRepository.getAvailableRidersCount(),
              builder: (context, availableRidersSnapshot) {
                return StreamBuilder<double>(
                  stream: _adminRepository.getTodayRevenue(),
                  builder: (context, revenueSnapshot) {
                    final metrics = [
                      _MetricData(
                        label: 'Active rides',
                        value: activeRidesSnapshot.data?.toString() ?? '--',
                        delta: '',
                        icon: Icons.local_taxi,
                        color: const Color(0xFF2DD4BF),
                      ),
                      _MetricData(
                        label: 'Available riders',
                        value:
                            availableRidersSnapshot.data?.toString() ?? '--',
                        delta: '',
                        icon: Icons.directions_car_filled,
                        color: const Color(0xFF60A5FA),
                      ),
                      _MetricData(
                        label: 'Revenue (24h)',
                        value:
                            'PKR ${NumberFormat.compact().format(revenueSnapshot.data ?? 0)}',
                        delta: '',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF34D399),
                      ),
                    ];
                    return _MetricsGrid(
                      isTablet: isTablet,
                      metrics: metrics,
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: _sectionGap),
        StreamBuilder<Map<String, double>>(
          stream: _adminRepository.watchRevenueByCity(),
          builder: (context, revenueSnapshot) {
            return StreamBuilder<Map<VehicleType, int>>(
              stream: _adminRepository.watchRideMix(),
              builder: (context, rideMixSnapshot) {
                return _ChartsSection(
                  isTablet: isTablet,
                  revenueByCity: revenueSnapshot.data ?? const {},
                  rideMix: rideMixSnapshot.data ?? const {},
                );
              },
            );
          },
        ),
        const SizedBox(height: _sectionGap),
        StreamBuilder<List<RideRequest>>(
          stream: _adminRepository.watchRecentRides(),
          builder: (context, ridesSnapshot) {
            return StreamBuilder<Map<String, AppUser>>(
              stream: _adminRepository.watchCustomersAndRiders(),
              builder: (context, usersSnapshot) {
                return _BottomSection(
                  isTablet: isTablet,
                  recentRides: ridesSnapshot.data ?? const [],
                  usersById: usersSnapshot.data ?? const {},
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRidesSection(bool isTablet) {
    return StreamBuilder<List<RideRequest>>(
      stream: _adminRepository.watchAllRides(),
      builder: (context, ridesSnapshot) {
        return StreamBuilder<Map<String, AppUser>>(
          stream: _adminRepository.watchCustomersAndRiders(),
          builder: (context, usersSnapshot) {
            return _RidesTable(
              title: 'All rides',
              emptyMessage: 'No rides found in Firestore yet.',
              rides: ridesSnapshot.data ?? const [],
              usersById: usersSnapshot.data ?? const {},
            );
          },
        );
      },
    );
  }

  Widget _buildUsersSection(UserRole role, bool isTablet) {
    return StreamBuilder<List<AppUser>>(
      stream: _adminRepository.watchUsersByRole(role),
      builder: (context, usersSnapshot) {
        return _UsersListCard(
          title: role.label,
          users: usersSnapshot.data ?? const [],
          emptyLabel: 'No ${role.label.toLowerCase()}s found',
        );
      },
    );
  }

  Widget _buildPlaceholderSection({required String title, required String message}) {
    return _PlaceholderCard(title: title, message: message);
  }


  Widget _buildPaymentsSection(bool isTablet) {
    return StreamBuilder<List<RideRequest>>(
      stream: _adminRepository.watchCompletedRides(),
      builder: (context, ridesSnapshot) {
        final rides = ridesSnapshot.data ?? const [];
        final total = rides.fold<double>(
          0,
          (sum, ride) => sum + ride.estimatedFare,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PaymentsSummary(total: total, count: rides.length),
            const SizedBox(height: 16),
            StreamBuilder<Map<String, AppUser>>(
              stream: _adminRepository.watchCustomersAndRiders(),
              builder: (context, usersSnapshot) {
                return _RidesTable(
                  title: 'Completed rides',
                  emptyMessage: 'No completed rides found yet.',
                  rides: rides,
                  usersById: usersSnapshot.data ?? const {},
                );
              },
            ),
          ],
        );
      },
    );
  }

}

class _AdminSidebar extends StatelessWidget {
  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onTapSignOut;

  const _AdminSidebar({
    required this.selectedSection,
    required this.onSelect,
    required this.onTapSignOut,
  });

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
            isActive: selectedSection == AdminSection.overview,
            onTap: () => onSelect(AdminSection.overview),
          ),
          _SidebarItem(
            icon: Icons.route_outlined,
            label: 'Rides',
            isActive: selectedSection == AdminSection.rides,
            onTap: () => onSelect(AdminSection.rides),
          ),
          _SidebarItem(
            icon: Icons.people_alt_outlined,
            label: 'Customers',
            isActive: selectedSection == AdminSection.customers,
            onTap: () => onSelect(AdminSection.customers),
          ),
          _SidebarItem(
            icon: Icons.directions_car_filled_outlined,
            label: 'Riders',
            isActive: selectedSection == AdminSection.riders,
            onTap: () => onSelect(AdminSection.riders),
          ),
          _SidebarItem(
            icon: Icons.payments_outlined,
            label: 'Payments',
            isActive: selectedSection == AdminSection.payments,
            onTap: () => onSelect(AdminSection.payments),
          ),
          _SidebarItem(
            icon: Icons.support_agent_outlined,
            label: 'Support',
            isActive: selectedSection == AdminSection.support,
            onTap: () => onSelect(AdminSection.support),
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
  final List<_MetricData> metrics;

  const _MetricsGrid({required this.isTablet, required this.metrics});

  @override
  Widget build(BuildContext context) {
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
  final Map<String, double> revenueByCity;
  final Map<VehicleType, int> rideMix;

  const _ChartsSection({
    required this.isTablet,
    required this.revenueByCity,
    required this.rideMix,
  });

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

    final revenueBars = revenueByCity.entries
        .map((entry) => _BarData(entry.key, entry.value))
        .toList();

    final rideSplit = rideMix.entries
        .map((entry) =>
            _PieData(entry.key.id, entry.value.toDouble(), entry.key.color))
        .toList();

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
  final List<RideRequest> recentRides;
  final Map<String, AppUser> usersById;

  const _BottomSection({
    required this.isTablet,
    required this.recentRides,
    required this.usersById,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rides = recentRides
        .map(
          (ride) => _RideRow(
            ride.id,
            _displayName(usersById[ride.customerId], fallback: 'Customer'),
            ride.vehicleType.label,
            '${ride.distanceKm.toStringAsFixed(1)} km',
            _statusLabel(ride.status),
            'PKR ${NumberFormat.decimalPattern().format(ride.estimatedFare)}',
          ),
        )
        .toList(growable: false);

    final riders = usersById.values
        .where((user) => user.role == UserRole.rider)
        .take(6)
        .toList(growable: false);

    final customers = usersById.values
        .where((user) => user.role == UserRole.customer)
        .take(6)
        .toList(growable: false);

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
                rows: rides
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

    final usersCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riders & customers', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _UsersSection(
              label: 'Riders',
              users: riders,
              emptyLabel: 'No riders found',
            ),
            const SizedBox(height: 14),
            _UsersSection(
              label: 'Customers',
              users: customers,
              emptyLabel: 'No customers found',
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
          Expanded(flex: 2, child: usersCard),
        ],
      );
    }

    return Column(
      children: [ridesTable, const SizedBox(height: 16), usersCard],
    );
  }

  static String _displayName(AppUser? user, {required String fallback}) {
    if (user == null) return fallback;
    if (user.fullName.trim().isNotEmpty) return user.fullName;
    if (user.email.trim().isNotEmpty) return user.email;
    return fallback;
  }

  static String _statusLabel(RideStatus status) {
    return switch (status) {
      RideStatus.requested => 'Requested',
      RideStatus.booked => 'Booked',
      RideStatus.arrived => 'Arrived',
      RideStatus.inProgress => 'In progress',
      RideStatus.completed => 'Completed',
      RideStatus.cancelled => 'Cancelled',
    };
  }
}


class _RidesTable extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<RideRequest> rides;
  final Map<String, AppUser> usersById;

  const _RidesTable({
    required this.title,
    required this.emptyMessage,
    required this.rides,
    required this.usersById,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rides.isEmpty) {
      return _PlaceholderCard(
        title: title,
        message: emptyMessage,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ride')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Rider')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Fare')),
                  DataColumn(label: Text('Created')),
                ],
                rows: rides
                    .map(
                      (ride) => DataRow(
                        cells: [
                          DataCell(Text(ride.id)),
                          DataCell(Text(_displayName(usersById[ride.customerId]))),
                          DataCell(Text(_displayName(usersById[ride.riderId]))),
                          DataCell(Text(ride.vehicleType.label)),
                          DataCell(_StatusPill(status: _statusLabel(ride.status))),
                          DataCell(Text(
                            'PKR ${NumberFormat.decimalPattern().format(ride.estimatedFare)}',
                          )),
                          DataCell(Text(_formatDate(ride.createdAt))),
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
  }

  static String _displayName(AppUser? user) {
    if (user == null) return '--';
    if (user.fullName.trim().isNotEmpty) return user.fullName;
    if (user.email.trim().isNotEmpty) return user.email;
    return '--';
  }

  static String _statusLabel(RideStatus status) {
    return switch (status) {
      RideStatus.requested => 'Requested',
      RideStatus.booked => 'Booked',
      RideStatus.arrived => 'Arrived',
      RideStatus.inProgress => 'In progress',
      RideStatus.completed => 'Completed',
      RideStatus.cancelled => 'Cancelled',
    };
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('MMM d, h:mm a').format(date);
  }
}


class _PaymentsSummary extends StatelessWidget {
  final double total;
  final int count;

  const _PaymentsSummary({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.payments_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total revenue', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'PKR ${NumberFormat.decimalPattern().format(total)}',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Completed rides', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersListCard extends StatelessWidget {
  final String title;
  final List<AppUser> users;
  final String emptyLabel;

  const _UsersListCard({
    required this.title,
    required this.users,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (users.isEmpty)
              Text(emptyLabel, style: theme.textTheme.bodyMedium)
            else
              ...users.map(
                (user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      _initial(user),
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                  title: Text(
                    user.fullName.isNotEmpty ? user.fullName : user.email,
                  ),
                  subtitle: Text(user.email),
                  trailing: _RoleChip(role: user.role),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _initial(AppUser user) {
    final name = user.fullName.trim().isNotEmpty ? user.fullName : user.email;
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
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

class _UsersSection extends StatelessWidget {
  final String label;
  final List<AppUser> users;
  final String emptyLabel;

  const _UsersSection({
    required this.label,
    required this.users,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (users.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall)
        else
          ...users.map(
            (user) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Text(
                  _initial(user),
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
              title: Text(
                user.fullName.isNotEmpty ? user.fullName : user.email,
              ),
              subtitle: Text(user.email),
              trailing: _RoleChip(role: user.role),
            ),
          ),
      ],
    );
  }

  static String _initial(AppUser user) {
    final name = user.fullName.trim().isNotEmpty ? user.fullName : user.email;
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (role) {
      UserRole.customer => theme.colorScheme.secondary,
      UserRole.rider => theme.colorScheme.primary,
      UserRole.admin => theme.colorScheme.tertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
