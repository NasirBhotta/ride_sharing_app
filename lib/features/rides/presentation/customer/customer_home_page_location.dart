part of 'customer_home_page.dart';

extension _CustomerHomePageLocation on _CustomerHomePageState {
  Future<void> _initLocation() async {
    try {
      if (!await _ensurePermission()) {
        if (!mounted) return;
        setState(() {
          _loadingLoc = false;
          _pickupCtrl.text = 'Location permission required';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
      final ll = LatLng(pos.latitude, pos.longitude);
      final addr = await _addrFromLL(ll);
      if (!mounted) return;
      setState(() {
        _currentLoc = ll;
        _loadingLoc = false;
        _pickupCtrl.text = addr;
      });
      await _moveCamera(ll);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      final ll =
          last == null
              ? _CustomerHomePageState._fallback
              : LatLng(last.latitude, last.longitude);
      final addr = await _addrFromLL(ll);
      if (!mounted) return;
      setState(() {
        _currentLoc = ll;
        _loadingLoc = false;
        _pickupCtrl.text = addr;
      });
      await _moveCamera(ll);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Using fallback location. Set emulator location from Extended Controls > Location.',
          ),
        ),
      );
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

  Future<String> _addrFromLL(LatLng p) async {
    try {
      final marks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (marks.isEmpty) return _coord(p);
      final m = marks.first;
      final parts =
          [m.name, m.locality, m.administrativeArea]
              .whereType<String>()
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();
      return parts.isEmpty ? _coord(p) : parts.join(', ');
    } catch (_) {
      return _coord(p);
    }
  }

  String _coord(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  Future<bool> _resolveDropoff() async {
    final q = _dropoffCtrl.text.trim();
    if (q.isEmpty) return false;
    try {
      final locs = await locationFromAddress(q);
      if (locs.isEmpty) return false;
      final ll = LatLng(locs.first.latitude, locs.first.longitude);
      final addr = await _addrFromLL(ll);
      if (!mounted) return false;
      setState(() {
        _dropoffLatLng = ll;
        _dropoffCtrl.text = addr;
      });
      await _moveCamera(ll);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that dropoff location.')),
      );
      return false;
    }
  }

  Future<void> _onMapTapped(LatLng p) async {
    if (_hasRide) return;
    final addr = await _addrFromLL(p);
    if (!mounted) return;
    setState(() {
      _dropoffLatLng = p;
      _dropoffCtrl.text = addr;
    });
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
    await _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  // ── Route ─────────────────────────────────────────────────────────
}
