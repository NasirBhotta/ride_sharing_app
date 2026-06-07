part of 'customer_home_page.dart';

extension _CustomerHomePageActions on _CustomerHomePageState {
  double _rad(double d) => d * pi / 180;

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  double get _distKm =>
      (_currentLoc != null && _dropoffLatLng != null)
          ? _haversineKm(_currentLoc!, _dropoffLatLng!)
          : 5.0;

  double _fare(VehicleType t) => (3.25 + _distKm * 1.15) * t.multiplier;

  // ── Ride lifecycle ────────────────────────────────────────────────

  void _watchRide(String id) {
    _rideSub?.cancel();
    _lastRouteStatus = null;
    _rideSub = _rideRepo
        .watchRide(id)
        .listen(
          (ride) {
            if (!mounted) return;
            final prev = _activeRide?.status;
            setState(() => _activeRide = ride);

            if (ride.status != prev) {
              final msg = switch (ride.status) {
                RideStatus.booked => 'Driver booked your ride.',
                RideStatus.arrived => 'Driver has arrived.',
                RideStatus.inProgress => 'Ride in progress.',
                RideStatus.completed => 'Ride completed.',
                RideStatus.cancelled => 'Ride cancelled.',
                _ => null,
              };
              if (msg != null)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
            }

            unawaited(_updateRoute(ride));
            _applyProgress(ride);

            if (ride.status == RideStatus.booked &&
                ride.status != prev &&
                _currentLoc != null &&
                ride.riderLat != null &&
                ride.riderLng != null) {
              unawaited(
                _fitBounds(
                  _currentLoc!,
                  LatLng(ride.riderLat!, ride.riderLng!),
                ),
              );
            }

            if (ride.status == RideStatus.completed ||
                ride.status == RideStatus.cancelled) {
              _rideSub?.cancel();
              _radiusTimer?.cancel();
              _posSub?.cancel();
              setState(() {
                _activeRideId = null;
                _activeRide = null;
                _lastRouteStatus = null;
                _routeInfo = null;
              });
              _clearPolylines();
            }
          },
          onError: (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Ride tracking failed: $e')));
          },
        );
  }

  void _startRadiusExpansion(String id) {
    _radiusTimer?.cancel();
    _searchRadiusKm = _CustomerHomePageState._initialRadiusKm;
    _radiusTimer = Timer.periodic(_CustomerHomePageState._radiusStepInterval, (
      t,
    ) async {
      final ride = _activeRide;
      if (ride == null ||
          ride.status != RideStatus.requested ||
          _searchRadiusKm >= _CustomerHomePageState._maxRadiusKm) {
        t.cancel();
        return;
      }
      _searchRadiusKm = min(
        _searchRadiusKm + _CustomerHomePageState._radiusStepKm,
        _CustomerHomePageState._maxRadiusKm,
      );
      await _rideRepo.expandSearchRadius(
        rideId: id,
        newRadiusKm: _searchRadiusKm,
        maxRadiusKm: _CustomerHomePageState._maxRadiusKm,
      );
      if (mounted) setState(() {});
    });
  }

  void _startLocationUpdates(String id) {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      double heading = pos.heading.isNaN ? 0 : pos.heading;

      // FIX #1: setState so HUD and map rebuild with new position
      if (!mounted) return;
      setState(() {
        _currentLoc = ll;
        _currentHeading = heading;
      });

      if (_activeRideId != null)
        _rideRepo.updateCustomerLocation(
          rideId: id,
          lat: ll.latitude,
          lng: ll.longitude,
        );

      // FIX #2 + #7: Move camera with tilt and bearing during navigation
      if (_activeRide?.status == RideStatus.inProgress) {
        unawaited(_moveCameraNav(ll, heading, zoom: 19.2));
        _checkVoicePrompt(ll); // FIX #12
      }

      final ride = _activeRide;
      if (ride != null) _applyProgress(ride);
    });
  }

  Future<void> _requestRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_dropoffCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a dropoff location.')),
      );
      return;
    }
    if (_dropoffLatLng == null && !await _resolveDropoff()) return;
    if (_currentLoc == null || _dropoffLatLng == null) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup/dropoff not ready yet.')),
      );
      return;
    }
    setState(() => _isRequesting = true);
    try {
      final req = RideRequest(
        id: '',
        customerId: user.uid,
        riderId: null,
        pickup: _pickupCtrl.text.trim(),
        dropoff: _dropoffCtrl.text.trim(),
        status: RideStatus.requested,
        vehicleType: _vehicle,
        estimatedFare: _fare(_vehicle),
        distanceKm: _distKm,
        createdAt: null,
        pickupLat: _currentLoc!.latitude,
        pickupLng: _currentLoc!.longitude,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        customerLat: _currentLoc!.latitude,
        customerLng: _currentLoc!.longitude,
        riderLat: null,
        riderLng: null,
        searchRadiusKm: _CustomerHomePageState._initialRadiusKm,
        maxRadiusKm: _CustomerHomePageState._maxRadiusKm,
      );
      final id = await _rideRepo.requestRide(req);
      if (!mounted) return;
      setState(() {
        _activeRideId = id;
        _searchRadiusKm = _CustomerHomePageState._initialRadiusKm;
      });
      _watchRide(id);
      _startRadiusExpansion(id);
      _startLocationUpdates(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // FIX #10: Removed erroneous ×50 multiplier — _fare() already returns PKR-equivalent
            '${_vehicle.label} requested. Est. PKR ${_fare(_vehicle).toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request ride: $e')));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _cancelRide() async {
    if (_activeRideId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel ride?'),
            content: const Text(
              'Do you want to cancel your current ride request?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel ride'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _isCancelling = true);
    try {
      await _rideRepo.cancelRide(_activeRideId!);
      _clearPolylines();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _sendMessage() async {
    final id = _activeRideId;
    final user = FirebaseAuth.instance.currentUser;
    if (id == null || user == null) return;
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    await _rideRepo.sendMessage(
      rideId: id,
      senderId: user.uid,
      senderRole: 'customer',
      text: text,
    );
  }

  // ── Getters ───────────────────────────────────────────────────────
}
