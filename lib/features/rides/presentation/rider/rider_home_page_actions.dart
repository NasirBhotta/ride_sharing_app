part of 'rider_home_page.dart';

extension _RiderHomePageActions on _RiderHomePageState {
  Future<void> _acceptRide(String id) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;
    try {
      LatLng? ll = _currentLoc;
      if (ll == null) {
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(const Duration(seconds: 8));
          ll = LatLng(p.latitude, p.longitude);
        } catch (_) {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) ll = LatLng(last.latitude, last.longitude);
        }
      }

      // Get ride to extract customerId for encryption key generation
      final rideDoc = await _rideRepo.watchRide(id).first;

      // Derive master keys from user IDs (simplified approach)
      final encryptionService = EncryptionService();
      final riderMasterKey =
          encryptionService.deriveKeyFromPassword(riderId);
      final customerMasterKey =
          encryptionService.deriveKeyFromPassword(rideDoc.customerId);

      final riderInfo = await _userRepo.getRiderSnapshot(riderId);

      await _rideRepo.acceptRide(
        rideId: id,
        riderId: riderId,
        customerId: rideDoc.customerId,
        riderMasterKey: riderMasterKey,
        customerMasterKey: customerMasterKey,
        riderInfo: riderInfo,
        riderLat: ll?.latitude,
        riderLng: ll?.longitude,
      );
      if (!mounted) return;
      if (ll != null) _currentLoc = ll;
      setState(() => _activeRideId = id);
      _watchRide(id);
      _startLocUpdates(id);
      _panelCtrl.forward();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride accepted!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    }
  }

  Future<void> _markArrived() async {
    if (_activeRideId != null) await _rideRepo.markArrived(_activeRideId!);
  }

  Future<void> _startRide() async {
    if (_activeRideId != null) await _rideRepo.startRide(_activeRideId!);
  }

  Future<void> _completeRide() async {
    if (_activeRideId != null) await _rideRepo.completeRide(_activeRideId!);
  }

  void _openChat() {
    final id = _activeRideId;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideChatScreen(rideId: id),
      ),
    );
  }

  void _watchRide(String id) {
    _rideSub?.cancel();
    _lastRouteStatus = null;
    _rideSub = _rideRepo.watchRide(id).listen((ride) {
      if (!mounted) return;
      final prev = _activeRide?.status;
      setState(() => _activeRide = ride);
      unawaited(_updateRoute(ride));

      if (ride.status == RideStatus.booked &&
          ride.status != prev &&
          _currentLoc != null &&
          ride.customerLat != null &&
          ride.customerLng != null) {
        unawaited(
          _fitBounds(
            _currentLoc!,
            LatLng(ride.customerLat!, ride.customerLng!),
          ),
        );
      }

      if (ride.status == RideStatus.completed ||
          ride.status == RideStatus.cancelled) {
        _rideSub?.cancel();
        _posSub?.cancel();
        _clearPolylines();
        _panelCtrl.reverse();
        setState(() {
          _activeRideId = null;
          _activeRide = null;
          _lastRouteStatus = null;
          _routeInfo = null;
        });
      }
    });
  }

  void _startLocUpdates(String id) {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);

      // FIX #1: setState so HUD and map rebuild with new position
      if (!mounted) return;
      setState(() {
        _currentLoc = ll;
        _currentHeading = pos.heading.isNaN ? 0 : pos.heading;
      });

      _rideRepo.updateRiderLocation(
        rideId: id,
        lat: ll.latitude,
        lng: ll.longitude,
      );

      // FIX #2 + #7: Move camera with tilt and bearing during active navigation
      final navStatus = _activeRide?.status;
      if (navStatus == RideStatus.booked ||
          navStatus == RideStatus.inProgress) {
        final navZoom = navStatus == RideStatus.inProgress ? 19.2 : 18.2;
        unawaited(_moveCameraNav(ll, _currentHeading, zoom: navZoom));
        if (_showHUD) _checkVoicePrompt(ll); // FIX #12
      }

      final ride = _activeRide;
      if (ride != null) _applyProgress(ride);
    });
  }

  // ── Getters ───────────────────────────────────────────────────────
}
