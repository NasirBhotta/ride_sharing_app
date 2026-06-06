part of 'rider_home_page.dart';

class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({
    required this.ride,
    required this.distanceKm,
    required this.onAccept,
    required this.isDark,
    required this.theme,
  });
  final RideRequest ride;
  final double? distanceKm;
  final VoidCallback onAccept;
  final bool isDark;
  final ThemeData theme;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.ride.vehicleType) {
    VehicleType.bike => const Color(0xFF15BA78),
    VehicleType.car => const Color(0xFF1A6BFF),
    VehicleType.premium => const Color(0xFFAA7BFF),
  };

  IconData get _icon => switch (widget.ride.vehicleType) {
    VehicleType.bike => Icons.two_wheeler_rounded,
    VehicleType.car => Icons.local_taxi_rounded,
    VehicleType.premium => Icons.directions_car_filled_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final ride = widget.ride;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF181C26) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                widget.isDark
                    ? const Color(0xFF252A3A)
                    : const Color(0xFFE5E9F5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride.vehicleType.label} ride',
                        style: widget.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 12,
                            color:
                                widget.isDark
                                    ? const Color(0xFF8B93A7)
                                    : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ride.distanceKm.toStringAsFixed(1)} km trip  ·  ${widget.distanceKm?.toStringAsFixed(1) ?? '--'} km away',
                            style: widget.theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${ride.estimatedFare.toStringAsFixed(2)}',
                      style: widget.theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'est. fare',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            widget.isDark
                                ? const Color(0xFF8B93A7)
                                : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RoutePreview(
              pickup: ride.pickup,
              dropoff: ride.dropoff,
              isDark: widget.isDark,
              theme: widget.theme,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTapDown: (_) => _ctrl.reverse(),
              onTapUp: (_) {
                _ctrl.forward();
                widget.onAccept();
              },
              onTapCancel: () => _ctrl.forward(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Accept ride',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({
    required this.pickup,
    required this.dropoff,
    required this.isDark,
    required this.theme,
  });
  final String pickup;
  final String dropoff;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final line = isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF15BA78),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 1.5, height: 26, color: line),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                dropoff,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
