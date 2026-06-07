import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    this.startLocation, // FIX #9: step start location for accurate detection
  });

  final String instruction;
  final double distanceM;
  final ManeuverType maneuver;
  final List<LatLng> polylinePoints;
  final LatLng? startLocation; // FIX #9
}

/// Summary info parsed from the Directions API for the bottom ETA sheet.
class RouteInfo {
  const RouteInfo({
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.steps,
  });

  final double totalDistanceM;
  final int totalDurationSec;
  final List<NavStep> steps;
}
