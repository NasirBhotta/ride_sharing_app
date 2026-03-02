import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/config/maps_config.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ride_repository.dart';
import '../domain/ride_message.dart';
import '../domain/ride_request.dart';
import '../domain/vehicle_type.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key});

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  final _rideRepository = RideRepository();
  final _authRepository = AuthRepository();
  final _messageController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _loadingLocation = true;
  bool _loadingRoute = false;

  String? _activeRideId;
  RideRequest? _activeRide;
  StreamSubscription<RideRequest>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;

  Set<Polyline> _polylines = {};

  static const _fallbackLocation = LatLng(37.42796133580664, -122.085749655962);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _mapController?.dispose();
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });

      await _moveCamera(_currentLocation!);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      final latLng =
          last == null
              ? _fallbackLocation
              : LatLng(last.latitude, last.longitude);
      if (!mounted) return;
      setState(() {
        _currentLocation = latLng;
        _loadingLocation = false;
      });
      await _moveCamera(latLng);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location service on the emulator.'),
        ),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _moveCamera(LatLng target) async {
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  Future<void> _fitMapToBounds(LatLng a, LatLng b) async {
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
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 64),
    );
  }

  Future<void> _updateDirectionsForRide(RideRequest ride) async {
    if (MapsConfig.directionsApiKey == 'YOUR_GOOGLE_DIRECTIONS_API_KEY') {
      return;
    }

    LatLng? origin;
    LatLng? destination;

    if (ride.status == RideStatus.booked) {
      if (_currentLocation != null &&
          ride.pickupLat != null &&
          ride.pickupLng != null) {
        origin = _currentLocation!;
        destination = LatLng(ride.pickupLat!, ride.pickupLng!);
      }
    } else if (ride.status == RideStatus.inProgress) {
      if (_currentLocation != null &&
          ride.dropoffLat != null &&
          ride.dropoffLng != null) {
        origin = _currentLocation!;
        destination = LatLng(ride.dropoffLat!, ride.dropoffLng!);
      }
    } else {
      _clearPolylines();
      return;
    }

    if (origin == null || destination == null) {
      _clearPolylines();
      return;
    }

    setState(() => _loadingRoute = true);
    final points = PolylinePoints();
    late final PolylineResult result;
    try {
      result = await points.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: MapsConfig.directionsApiKey,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRoute = false);
      return;
    }

    if (!mounted) return;
    if (result.points.isEmpty) {
      setState(() {
        _polylines = {};
        _loadingRoute = false;
      });
      return;
    }

    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Theme.of(context).colorScheme.primary,
      width: 6,
      points: result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false),
    );

    setState(() {
      _polylines = {polyline};
      _loadingRoute = false;
    });
  }

  void _clearPolylines() {
    if (_polylines.isNotEmpty) {
      setState(() => _polylines = {});
    }
  }

  double _toRad(double degree) => degree * pi / 180;

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);

    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  double? _distanceToRideKm(RideRequest ride) {
    if (_currentLocation == null ||
        ride.pickupLat == null ||
        ride.pickupLng == null) {
      return null;
    }
    return _haversineKm(
      _currentLocation!,
      LatLng(ride.pickupLat!, ride.pickupLng!),
    );
  }

  bool _withinRadius(RideRequest ride) {
    final distance = _distanceToRideKm(ride);
    if (distance == null) return false;
    return distance <= ride.searchRadiusKm;
  }

  void _startWatchingRide(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _rideRepository.watchRide(rideId).listen((ride) {
      if (!mounted) return;
      setState(() => _activeRide = ride);

      unawaited(_updateDirectionsForRide(ride));

      if (_currentLocation != null &&
          ride.customerLat != null &&
          ride.customerLng != null) {
        unawaited(
          _fitMapToBounds(
            _currentLocation!,
            LatLng(ride.customerLat!, ride.customerLng!),
          ),
        );
      }

      if (ride.status == RideStatus.completed ||
          ride.status == RideStatus.cancelled) {
        _rideSubscription?.cancel();
        _positionSubscription?.cancel();
        setState(() {
          _activeRideId = null;
          _activeRide = null;
        });
      }
    });
  }

  void _startRiderLocationUpdates(String rideId) {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLocation = latLng;
      _rideRepository.updateRiderLocation(
        rideId: rideId,
        lat: latLng.latitude,
        lng: latLng.longitude,
      );
    });
  }

  Future<void> _acceptRide(String rideId) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    try {
      await _rideRepository.acceptRide(rideId: rideId, riderId: riderId);
      if (!mounted) return;
      setState(() => _activeRideId = rideId);
      _startWatchingRide(rideId);
      _startRiderLocationUpdates(rideId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride booked.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept ride: $error')));
    }
  }

  Future<void> _markArrived() async {
    if (_activeRideId == null) return;
    await _rideRepository.markArrived(_activeRideId!);
    _clearPolylines();
  }

  Future<void> _startRide() async {
    if (_activeRideId == null) return;
    await _rideRepository.startRide(_activeRideId!);
  }

  Future<void> _completeRide() async {
    if (_activeRideId == null) return;
    await _rideRepository.completeRide(_activeRideId!);
    _clearPolylines();
  }

  Future<void> _sendMessage() async {
    final rideId = _activeRideId;
    final user = FirebaseAuth.instance.currentUser;
    if (rideId == null || user == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await _rideRepository.sendMessage(
      rideId: rideId,
      senderId: user.uid,
      senderRole: 'rider',
      text: text,
    );
  }

  bool get _hasActiveRide => _activeRideId != null;

  String get _statusLabel {
    return switch (_activeRide?.status) {
      RideStatus.booked => 'Navigate to pickup',
      RideStatus.arrived => 'Waiting for rider to start',
      RideStatus.inProgress => 'Ride in progress',
      RideStatus.completed => 'Ride completed',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _currentLocation ?? _fallbackLocation;
    final customerLat = _activeRide?.customerLat ?? _activeRide?.pickupLat;
    final customerLng = _activeRide?.customerLng ?? _activeRide?.pickupLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            onPressed: _authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: mapCenter,
                      zoom: 14,
                    ),
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_currentLocation != null) {
                        _moveCamera(_currentLocation!);
                      }
                    },
                    myLocationEnabled: _currentLocation != null,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    polylines: _polylines,
                    markers: {
                      Marker(
                        markerId: const MarkerId('rider'),
                        position: mapCenter,
                        infoWindow: const InfoWindow(title: 'You'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                      if (customerLat != null && customerLng != null)
                        Marker(
                          markerId: const MarkerId('customer'),
                          position: LatLng(customerLat, customerLng),
                          infoWindow: const InfoWindow(title: 'Customer'),
                        ),
                    },
                  ),
                ),
              ),
            ),
            if (_loadingLocation) const LinearProgressIndicator(minHeight: 2),
            if (_loadingRoute) const LinearProgressIndicator(minHeight: 2),
            if (_hasActiveRide)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusLabel, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _markArrived,
                            child: const Text('Arrived'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _startRide,
                            child: const Text('Start Ride'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _completeRide,
                            child: const Text('Complete'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Messages', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: StreamBuilder<List<RideMessage>>(
                        stream: _rideRepository.watchMessages(_activeRideId!),
                        builder: (context, snapshot) {
                          final messages = snapshot.data ?? [];
                          if (messages.isEmpty) {
                            return const Center(
                              child: Text('No messages yet.'),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return ListTile(
                                dense: true,
                                title: Text(message.text),
                                subtitle: Text(message.senderRole),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Message customer',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: StreamBuilder<List<RideRequest>>(
                  stream: _rideRepository.watchRequestedRides(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Failed to load ride requests.'),
                      );
                    }

                    final rides = (snapshot.data ?? [])
                        .where(_withinRadius)
                        .toList(growable: false);

                    if (rides.isEmpty) {
                      return const Center(
                        child: Text('No nearby requests right now.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ride = rides[index];
                        final distance = _distanceToRideKm(ride);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${ride.vehicleType.label} ride',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Chip(
                                      label: Text(
                                        '~\$${ride.estimatedFare.toStringAsFixed(2)}',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text('Pickup: ${ride.pickup}'),
                                Text('Dropoff: ${ride.dropoff}'),
                                Text(
                                  'Distance: ${distance?.toStringAsFixed(1) ?? '--'} km | Radius: ${ride.searchRadiusKm.toStringAsFixed(0)} km',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _acceptRide(ride.id),
                                    child: const Text('Accept ride'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
