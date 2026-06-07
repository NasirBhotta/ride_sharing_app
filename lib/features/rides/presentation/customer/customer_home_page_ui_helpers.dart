part of 'customer_home_page.dart';

extension _CustomerHomePageUiHelpers on _CustomerHomePageState {
  bool get _hasRide => _activeRideId != null;

  bool get _showHUD =>
      _routeInfo != null &&
      _activeRide != null &&
      _activeRide!.status == RideStatus.inProgress;

  String get _statusLabel => switch (_activeRide?.status) {
    RideStatus.requested =>
      'Searching nearby drivers (${_searchRadiusKm.toStringAsFixed(0)} km)...',
    RideStatus.booked => 'Driver booked. On the way.',
    RideStatus.arrived => 'Driver has arrived.',
    RideStatus.inProgress => 'Ride in progress.',
    RideStatus.completed => 'Ride completed.',
    RideStatus.cancelled => 'Ride cancelled.',
    _ => '',
  };

  Color _statusColor(ThemeData t) => switch (_activeRide?.status) {
    RideStatus.booked => Colors.green,
    RideStatus.arrived => t.colorScheme.primary,
    RideStatus.inProgress => t.colorScheme.primary,
    RideStatus.cancelled => t.colorScheme.error,
    _ => t.colorScheme.secondary,
  };

  // ── Route badge ───────────────────────────────────────────────────

  Widget _routeBadge(ThemeData theme) {
    if (_routeState == _RouteState.idle || _routeState == _RouteState.success)
      return const SizedBox.shrink();
    final (icon, color, label) = switch (_routeState) {
      _RouteState.loading => (
        Icons.route_outlined,
        theme.colorScheme.primary,
        'Loading route…',
      ),
      _RouteState.noApiKey => (
        Icons.vpn_key_off_outlined,
        theme.colorScheme.error,
        'Directions API key not set',
      ),
      _RouteState.missingCoords => (
        Icons.location_off_outlined,
        Colors.orange,
        'Route coords not available yet',
      ),
      _RouteState.apiError => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        'Directions API error',
      ),
      _RouteState.emptyResult => (
        Icons.directions_off_outlined,
        Colors.orange,
        'No driveable route found',
      ),
      _RouteState.exception => (
        Icons.error_outline,
        theme.colorScheme.error,
        'Route fetch failed',
      ),
      _ => (Icons.info_outline, theme.colorScheme.secondary, ''),
    };
    return GestureDetector(
      onTap:
          _routeError == null
              ? null
              : () => showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder:
                    (_) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Route diagnostic',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(_routeError!, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_routeError != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 13, color: color.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
}
