part of 'rider_home_page.dart';

extension _RiderHomePageRideList on _RiderHomePageState {
  Widget _buildRideList(ThemeData theme, bool isDark, {bool embedded = false}) {
    return StreamBuilder<List<RideRequest>>(
      stream: _rideRepo.watchRequestedRides(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color:
                      isDark
                          ? const Color(0xFF8B93A7)
                          : const Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load ride requests.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }
        final rides = (snap.data ?? [])
            .where(_withinRadius)
            .toList(growable: false);
        if (rides.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E2235)
                            : const Color(0xFFF0F3FC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 34,
                    color:
                        isDark
                            ? const Color(0xFF8B93A7)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),
                Text('No nearby requests', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'New ride requests will appear here.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding:
              embedded
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(16, 8, 16, 24),
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder:
              (_, i) => _RideRequestCard(
                ride: rides[i],
                distanceKm: _distToRideKm(rides[i]),
                onAccept: () => _acceptRide(rides[i].id),
                isDark: isDark,
                theme: theme,
              ),
        );
      },
    );
  }
}
