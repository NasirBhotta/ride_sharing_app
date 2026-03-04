import 'package:flutter/material.dart';

import '../../domain/vehicle_type.dart';

class VehicleOptionCard extends StatefulWidget {
  const VehicleOptionCard({
    super.key,
    required this.type,
    required this.selected,
    required this.fare,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final double fare;
  final VoidCallback onTap;

  @override
  State<VehicleOptionCard> createState() => _VehicleOptionCardState();
}

class _VehicleOptionCardState extends State<VehicleOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.97,
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

  // ── Icon + accent per vehicle type ──────────────────────────────
  (IconData, Color) get _typeStyle => switch (widget.type) {
    VehicleType.bike => (Icons.two_wheeler_rounded, const Color(0xFF15BA78)),
    VehicleType.car => (Icons.local_taxi_rounded, const Color(0xFF1A6BFF)),
    VehicleType.premium => (
      Icons.directions_car_filled_rounded,
      const Color(0xFFAA7BFF),
    ),
  };

  String get _badge => switch (widget.type) {
    VehicleType.bike => 'ECO',
    VehicleType.car => 'STANDARD',
    VehicleType.premium => 'PREMIUM',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (icon, accent) = _typeStyle;
    final sel = widget.selected;

    final cardBg =
        sel
            ? (isDark ? accent.withOpacity(0.12) : accent.withOpacity(0.07))
            : (isDark ? const Color(0xFF181C26) : Colors.white);

    final borderColor =
        sel
            ? accent
            : (isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5));

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: sel ? 2 : 1.5),
            boxShadow:
                sel
                    ? [
                      BoxShadow(
                        color: accent.withOpacity(isDark ? 0.18 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.20 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: Row(
            children: [
              // ── Icon container ──────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      sel
                          ? accent.withOpacity(0.18)
                          : (isDark
                              ? const Color(0xFF1E2235)
                              : const Color(0xFFF4F6FB)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color:
                      sel
                          ? accent
                          : (isDark
                              ? const Color(0xFF8B93A7)
                              : const Color(0xFF6B7280)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // ── Labels ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.type.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                sel
                                    ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF0D1021))
                                    : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(sel ? 0.18 : 0.09),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color:
                              isDark
                                  ? const Color(0xFF8B93A7)
                                  : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'ETA ${widget.type.eta}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Fare ─────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${(widget.fare * 50).toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: sel ? accent : null,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'est. fare',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isDark
                              ? const Color(0xFF8B93A7)
                              : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              // ── Selected check ────────────────────────────────────
              if (sel) ...[
                const SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
