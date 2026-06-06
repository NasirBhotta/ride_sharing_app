part of 'rider_home_page.dart';

extension _RiderHomePageLocation on _RiderHomePageState {
  Future<void> _initLocation() async {
    try {
      if (!await _ensurePermission()) {
        if (mounted) setState(() => _loadingLoc = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _currentLoc = LatLng(pos.latitude, pos.longitude);
        _currentHeading = pos.heading.isNaN ? 0 : pos.heading;
        _loadingLoc = false;
      });
      await _moveCamera(_currentLoc!);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      final ll =
          last == null
              ? _RiderHomePageState._fallback
              : LatLng(last.latitude, last.longitude);
      if (!mounted) return;
      setState(() {
        _currentLoc = ll;
        _loadingLoc = false;
      });
      await _moveCamera(ll);
    }
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p != LocationPermission.denied &&
        p != LocationPermission.deniedForever;
  }

  Future<void> _moveCamera(LatLng t) async =>
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(t, 15));

  // FIX #2 + #7: Navigation camera tracks position with tilt and bearing
  Future<void> _moveCameraNav(
    LatLng t,
    double heading, {
    double zoom = 18.2,
  }) async => _mapCtrl?.animateCamera(
    CameraUpdate.newCameraPosition(
      CameraPosition(target: t, zoom: zoom, tilt: 55, bearing: heading),
    ),
  );

  Future<void> _fitBounds(LatLng a, LatLng b) async {
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(a.latitude, b.latitude),
        min(a.longitude, b.longitude),
      ),
      northeast: LatLng(
        max(a.latitude, b.latitude),
        max(a.longitude, b.longitude),
      ),
    );
    await _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ── Route ─────────────────────────────────────────────────────────
}
