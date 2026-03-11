import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/ride_request.dart';

enum ManeuverType {
  straight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  uTurn,
  roundabout,
  arrive,
}

class NavStep {
  const NavStep({
    required this.instruction,
    required this.distanceM,
    required this.maneuver,
    required this.polylinePoints,
  });

  final String instruction;
  final double distanceM;
  final ManeuverType maneuver;
  final List<LatLng> polylinePoints;
}

// ─────────────────────────────────────────────────────────────────────────────
// NavigationHUD
//
// Place inside a Stack on top of a GoogleMap.
// Renders a compact green top banner (current instruction) and a slim
// coloured bottom bar (ETA + remaining distance + arrival time).
// No full-screen mode — it lives inside whatever height the map has.
// ─────────────────────────────────────────────────────────────────────────────

class NavigationHUD extends StatefulWidget {
  const NavigationHUD({
    super.key,
    required this.steps,
    required this.currentPos,
    required this.totalDistM,
    required this.etaSeconds,
    required this.rideStatus,
  });

  final List<NavStep> steps;
  final LatLng currentPos;
  final double totalDistM;
  final int etaSeconds;
  final RideStatus rideStatus;

  @override
  State<NavigationHUD> createState() => _NavigationHUDState();
}

class _NavigationHUDState extends State<NavigationHUD>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  int _stepIndex = 0;
  double _remainDistM = 0;
  int _remainEtaSec = 0;

  @override
  void initState() {
    super.initState();
    _remainDistM = widget.totalDistM;
    _remainEtaSec = widget.etaSeconds;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _recalc();
  }

  @override
  void didUpdateWidget(NavigationHUD old) {
    super.didUpdateWidget(old);
    if (old.currentPos != widget.currentPos) _recalc();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _recalc() {
    if (widget.steps.isEmpty) return;
    double best = double.infinity;
    int bestIdx = _stepIndex;
    final limit = (_stepIndex + 4).clamp(0, widget.steps.length);
    for (var i = _stepIndex; i < limit; i++) {
      for (final p in widget.steps[i].polylinePoints) {
        final d = _distM(widget.currentPos, p);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
      }
    }
    double rem = 0;
    for (var i = bestIdx; i < widget.steps.length; i++) {
      rem += widget.steps[i].distanceM;
    }
    final frac = widget.totalDistM > 0 ? rem / widget.totalDistM : 0.0;
    if (bestIdx != _stepIndex) {
      _ctrl.reset();
      _ctrl.forward();
    }
    if (mounted) {
      setState(() {
        _stepIndex = bestIdx;
        _remainDistM = rem;
        _remainEtaSec = (widget.etaSeconds * frac).round();
      });
    }
  }

  double _distM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _r(b.latitude - a.latitude);
    final dLon = _r(b.longitude - a.longitude);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_r(a.latitude)) * cos(_r(b.latitude)) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  double _r(double d) => d * pi / 180;

  NavStep? get _step =>
      widget.steps.isNotEmpty ? widget.steps[_stepIndex] : null;
  NavStep? get _next =>
      _stepIndex + 1 < widget.steps.length
          ? widget.steps[_stepIndex + 1]
          : null;

  String _dist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  String _eta(int s) =>
      s >= 3600
          ? '${s ~/ 3600} hr ${(s % 3600) ~/ 60} min'
          : '${(s / 60).ceil()} min';

  String _arrival() {
    final t = DateTime.now().add(Duration(seconds: _remainEtaSec));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  IconData _icon(ManeuverType m) => switch (m) {
    ManeuverType.turnLeft => Icons.turn_left_rounded,
    ManeuverType.turnRight => Icons.turn_right_rounded,
    ManeuverType.slightLeft => Icons.turn_slight_left_rounded,
    ManeuverType.slightRight => Icons.turn_slight_right_rounded,
    ManeuverType.uTurn => Icons.u_turn_left_rounded,
    ManeuverType.roundabout => Icons.roundabout_left_rounded,
    ManeuverType.arrive => Icons.location_on_rounded,
    _ => Icons.straight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final step = _step;
    if (step == null) return const SizedBox.shrink();

    final isBooked = widget.rideStatus == RideStatus.booked;
    const topBg = Color(0xFF1B4332);
    const topBgDark = Color(0xFF0D2B1E);
    final bottomBg =
        isBooked ? const Color(0xFF1565C0) : const Color(0xFF4A148C);

    return Stack(
      children: [
        // ── Instruction banner (top) ───────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current step
                Container(
                  color: topBg,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _icon(step.maneuver),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dist(step.distanceM),
                              style: const TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              step.instruction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Next step "then" row
                if (_next != null)
                  Container(
                    color: topBgDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Then  ',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          _icon(_next!.maneuver),
                          color: Colors.white54,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _next!.instruction,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── ETA bar (bottom) ───────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: bottomBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Text(
                  _eta(_remainEtaSec),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _dist(_remainDistM),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _arrival(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isBooked ? 'to pickup' : 'arrival',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
