part of 'rider_home_page.dart';

extension _RiderHomePageRoute on _RiderHomePageState {
  Future<void> _updateRoute(RideRequest ride, {bool force = false}) async {
    final isRouteStatus =
        ride.status == RideStatus.booked ||
        ride.status == RideStatus.inProgress;
    final hasLoadedRoute =
        _routeInfo != null && _routeState == _RouteState.success;
    if (!force &&
        ride.status == _lastRouteStatus &&
        (!isRouteStatus || hasLoadedRoute)) {
      if (mounted) setState(() {});
      return;
    }

    if (MapsConfig.directionsApiKey == 'YOUR_GOOGLE_DIRECTIONS_API_KEY') {
      if (mounted)
        setState(() {
          _routeState = _RouteState.noApiKey;
          _routeError = 'Replace directionsApiKey in maps_config.dart.';
          _polylines = {};
          _lastRouteStatus = ride.status;
        });
      return;
    }

    LatLng? origin, dest;

    if (ride.status == RideStatus.booked) {
      final oLat = _currentLoc?.latitude ?? ride.riderLat;
      final oLng = _currentLoc?.longitude ?? ride.riderLng;
      if (oLat != null &&
          oLng != null &&
          ride.pickupLat != null &&
          ride.pickupLng != null) {
        origin = LatLng(oLat, oLng);
        dest = LatLng(ride.pickupLat!, ride.pickupLng!);
      }
    } else if (ride.status == RideStatus.inProgress) {
      final oLat = _currentLoc?.latitude ?? ride.riderLat;
      final oLng = _currentLoc?.longitude ?? ride.riderLng;
      if (oLat != null &&
          oLng != null &&
          ride.dropoffLat != null &&
          ride.dropoffLng != null) {
        origin = LatLng(oLat, oLng);
        dest = LatLng(ride.dropoffLat!, ride.dropoffLng!);
      }
    } else {
      _clearPolylines();
      if (mounted)
        setState(() {
          _lastRouteStatus = ride.status;
          _routeInfo = null;
        });
      return;
    }

    if (origin == null || dest == null) {
      if (mounted)
        setState(() {
          _routeState = _RouteState.missingCoords;
          _routeError = 'Status ${ride.status.name}: coords not yet available.';
          _polylines = {};
          _routeInfo = null;
          _routePoints = [];
          _lastRouteStatus = ride.status;
        });
      return;
    }

    if (mounted) setState(() => _routeState = _RouteState.loading);

    try {
      // FIX #5: Add departure_time for accurate ETA
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '${origin.latitude},${origin.longitude}',
            'destination': '${dest.latitude},${dest.longitude}',
            'mode': 'driving',
            'departure_time': 'now',
            'alternatives': 'false',
            'key': MapsConfig.directionsApiKey,
          });
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _routeState = _RouteState.apiError;
          _routeError = 'HTTP ${res.statusCode}';
          _polylines = {};
          _routeInfo = null;
          _routePoints = [];
          _lastRouteStatus = ride.status;
        });
        return;
      }

      final info = RouteInfo.fromJson(res.body);
      if (info == null || info.steps.isEmpty) {
        final routeError =
            DirectionsParser.errorMessage(res.body) ??
            'No route returned by Directions API.';
        setState(() {
          _routeState = _RouteState.emptyResult;
          _routeError = routeError;
          _polylines = {};
          _routeInfo = null;
          _routePoints = [];
          _lastRouteStatus = ride.status;
        });
        return;
      }

      final pts = info.steps
          .expand((s) => s.polylinePoints)
          .toList(growable: false);

      setState(() {
        _routeInfo = info;
        _routePoints = pts;
        _closestPolylineIndex = 0; // FIX #3: reset on new route
        _routeState = _RouteState.success;
        _routeError = null;
        _lastRouteStatus = ride.status;
      });
      _applyProgress(ride);
      if (ride.status != RideStatus.inProgress &&
          ride.status != RideStatus.booked) {
        unawaited(_fitBounds(origin, dest));
      }

      // FIX #12: Speak first instruction
      if (info.steps.isNotEmpty) {
        _speakInstruction(info.steps.first.instruction);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeState = _RouteState.exception;
        _routeError = e.toString();
        _polylines = {};
        _routeInfo = null;
        _routePoints = [];
        _lastRouteStatus = ride.status;
      });
    }
  }

  void _clearPolylines() {
    if (_polylines.isNotEmpty ||
        _routeState != _RouteState.idle ||
        _routePoints.isNotEmpty) {
      if (mounted)
        setState(() {
          _polylines = {};
          _routeState = _RouteState.idle;
          _routeError = null;
          _routePoints = [];
          _routeInfo = null;
          _closestPolylineIndex = 0; // FIX #3
        });
    }
  }

  void _applyProgress(RideRequest ride) {
    if (_routePoints.isEmpty) return;
    LatLng? cur, dest;

    if (ride.status == RideStatus.booked) {
      final oLat = _currentLoc?.latitude ?? ride.riderLat;
      final oLng = _currentLoc?.longitude ?? ride.riderLng;
      if (oLat != null && oLng != null) cur = LatLng(oLat, oLng);
      if (ride.pickupLat != null && ride.pickupLng != null)
        dest = LatLng(ride.pickupLat!, ride.pickupLng!);
    } else if (ride.status == RideStatus.inProgress) {
      final oLat = _currentLoc?.latitude ?? ride.riderLat;
      final oLng = _currentLoc?.longitude ?? ride.riderLng;
      if (oLat != null && oLng != null) cur = LatLng(oLat, oLng);
      if (ride.dropoffLat != null && ride.dropoffLng != null)
        dest = LatLng(ride.dropoffLat!, ride.dropoffLng!);
    } else {
      return;
    }

    if (cur == null || dest == null) return;
    if (_haversineKm(cur, dest) * 1000 <= 25) {
      _clearPolylines();
      return;
    }

    // FIX #3: Windowed search starting from last known index
    final searchStart = _closestPolylineIndex;
    final searchEnd = min(searchStart + 30, _routePoints.length);

    var ci = searchStart;
    var cd = double.infinity;

    // Search the window first
    for (var i = searchStart; i < searchEnd; i++) {
      final d = _haversineKm(cur, _routePoints[i]);
      if (d < cd) {
        cd = d;
        ci = i;
      }
    }

    // If not found in window, fall back to full scan once
    if (ci == searchStart && searchStart > 0) {
      for (var i = 0; i < _routePoints.length; i++) {
        final d = _haversineKm(cur, _routePoints[i]);
        if (d < cd) {
          cd = d;
          ci = i;
        }
      }
    }

    _closestPolylineIndex = ci; // FIX #3: persist for next update

    // FIX #4: Off-route detection — if >40m from nearest point, reroute
    if (cd * 1000 > 40) {
      unawaited(_updateRoute(ride, force: true));
      return;
    }

    if (!mounted) return;
    final theme = Theme.of(context);

    setState(() {
      // FIX #6: Full route in gray + remaining route in primary color
      _polylines = {
        Polyline(
          polylineId: const PolylineId('full_route'),
          color: Colors.grey.shade300,
          width: 6,
          points: _routePoints,
        ),
        Polyline(
          polylineId: const PolylineId('traveled'),
          color: Colors.grey.shade400,
          width: 6,
          points: _routePoints.sublist(0, ci + 1),
        ),
        Polyline(
          polylineId: const PolylineId('remaining'),
          color: theme.colorScheme.primary,
          width: 6,
          points: _routePoints.sublist(ci),
        ),
      };
    });
  }

  // FIX #12: Voice navigation
  Future<void> _speakInstruction(String instruction) async {
    if (instruction == _lastSpokenInstruction) return;
    _lastSpokenInstruction = instruction;
    await _tts.speak(instruction);
  }

  void _checkVoicePrompt(LatLng cur) {
    final info = _routeInfo;
    if (info == null || info.steps.isEmpty) return;
    for (final step in info.steps) {
      final anchor =
          step.startLocation ??
          (step.polylinePoints.isNotEmpty ? step.polylinePoints.first : null);
      if (anchor == null) continue;
      final dist = _haversineKm(cur, anchor) * 1000;
      if (dist < 80) {
        _speakInstruction(step.instruction);
        break;
      }
    }
  }

  // ── Distance helpers ──────────────────────────────────────────────

  double _rad(double d) => d * pi / 180; //

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  double? _distToRideKm(RideRequest ride) {
    if (_currentLoc == null || ride.pickupLat == null || ride.pickupLng == null)
      return null;
    return _haversineKm(_currentLoc!, LatLng(ride.pickupLat!, ride.pickupLng!));
  }

  bool _withinRadius(RideRequest ride) {
    final d = _distToRideKm(ride);
    return d != null && d <= ride.searchRadiusKm;
  }

  // ── Ride actions ──────────────────────────────────────────────────
}
