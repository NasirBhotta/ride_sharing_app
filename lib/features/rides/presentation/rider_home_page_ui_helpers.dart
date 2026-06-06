part of 'rider_home_page.dart';

extension _RiderHomePageUiHelpers on _RiderHomePageState {
  bool get _hasRide => _activeRideId != null;

  bool get _showHUD =>
      _routeInfo != null &&
      _activeRide != null &&
      (_activeRide!.status == RideStatus.booked ||
          _activeRide!.status == RideStatus.inProgress);

  String get _statusLabel => switch (_activeRide?.status) {
    RideStatus.booked => 'Navigate to pickup',
    RideStatus.arrived => 'Waiting at pickup',
    RideStatus.inProgress => 'Ride in progress',
    RideStatus.completed => 'Ride completed',
    _ => '',
  };

  (Color, IconData) _statusStyle(ThemeData t) => switch (_activeRide?.status) {
    RideStatus.booked => (t.colorScheme.primary, Icons.navigation_rounded),
    RideStatus.arrived => (
      const Color(0xFF15BA78),
      Icons.where_to_vote_rounded,
    ),
    RideStatus.inProgress => (const Color(0xFFFF8C00), Icons.drive_eta_rounded),
    RideStatus.completed => (
      const Color(0xFF15BA78),
      Icons.check_circle_rounded,
    ),
    _ => (t.colorScheme.secondary, Icons.info_outline_rounded),
  };

  bool get _canMarkArrived => _activeRide?.status == RideStatus.booked;
  bool get _canStartRide => _activeRide?.status == RideStatus.arrived;
  bool get _canComplete => _activeRide?.status == RideStatus.inProgress;

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
        const Color(0xFFFF8C00),
        'Route coords unavailable',
      ),
      _RouteState.apiError => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        'Directions API error',
      ),
      _RouteState.emptyResult => (
        Icons.directions_off_outlined,
        const Color(0xFFFF8C00),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_routeError != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: color.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
}
