import 'dart:convert';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'navigation_hud.dart';

/// Parses a raw Google Directions API JSON response into a list of [NavStep].
class DirectionsParser {
  DirectionsParser._();

  static List<NavStep> parse(String jsonBody) {
    final Map<String, dynamic> data = json.decode(jsonBody);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    final legs = routes[0]['legs'] as List?;
    if (legs == null || legs.isEmpty) return [];

    final steps = legs[0]['steps'] as List?;
    if (steps == null) return [];

    return steps.map((s) => _parseStep(s as Map<String, dynamic>)).toList();
  }

  static NavStep _parseStep(Map<String, dynamic> step) {
    final html = step['html_instructions'] as String? ?? '';
    final instruction = _stripHtml(html);

    final distanceVal = (step['distance'] as Map?)?['value'] as num? ?? 0;

    final maneuver = _parseManeuver(step['maneuver'] as String?);

    final polyline = step['polyline']?['points'] as String? ?? '';
    final points =
        PolylinePoints()
            .decodePolyline(polyline)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

    // FIX #9: Store step start location for accurate step detection
    final startLoc = step['start_location'] as Map?;
    final startLatLng =
        startLoc != null
            ? LatLng(
              (startLoc['lat'] as num).toDouble(),
              (startLoc['lng'] as num).toDouble(),
            )
            : (points.isNotEmpty ? points.first : null);

    return NavStep(
      instruction: instruction,
      distanceM: distanceVal.toDouble(),
      maneuver: maneuver,
      polylinePoints: points,
      startLocation: startLatLng,
    );
  }

  /// Strips HTML tags from Directions API html_instructions.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<b>'), '')
        .replaceAll(RegExp(r'</b>'), '')
        .replaceAll(RegExp(r'<div[^>]*>'), ' · ')
        .replaceAll(RegExp(r'</div>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // FIX #8: Dart switch does not support || in case expressions — use separate cases
  static ManeuverType _parseManeuver(String? maneuver) => switch (maneuver) {
    'turn-left' => ManeuverType.turnLeft,
    'turn-right' => ManeuverType.turnRight,
    'turn-slight-left' => ManeuverType.slightLeft,
    'turn-slight-right' => ManeuverType.slightRight,
    'uturn-left' => ManeuverType.uTurn,
    'uturn-right' => ManeuverType.uTurn,
    'roundabout-left' => ManeuverType.roundabout,
    'roundabout-right' => ManeuverType.roundabout,
    'turn-sharp-left' => ManeuverType.roundabout,
    'turn-sharp-right' => ManeuverType.roundabout,
    _ => ManeuverType.straight,
  };
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

  static RouteInfo? fromJson(String jsonBody) {
    try {
      final Map<String, dynamic> data = json.decode(jsonBody);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final legs = routes[0]['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;

      final leg = legs[0] as Map<String, dynamic>;
      final distM =
          ((leg['distance'] as Map?)?['value'] as num? ?? 0).toDouble();
      final durSec = ((leg['duration'] as Map?)?['value'] as num? ?? 0).toInt();

      final steps = DirectionsParser.parse(jsonBody);

      return RouteInfo(
        totalDistanceM: distM,
        totalDurationSec: durSec,
        steps: steps,
      );
    } catch (_) {
      return null;
    }
  }
}
