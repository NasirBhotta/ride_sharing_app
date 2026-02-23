import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../data/ride_repository.dart';
import '../domain/ride_request.dart';
import '../domain/vehicle_type.dart';
import 'widgets/ride_location_fields.dart';
import 'widgets/vehicle_option_card.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _rideRepository = RideRepository();
  final _authRepository = AuthRepository();
  final _pickupController = TextEditingController(
    text: 'Detecting location...',
  );
  final _dropoffController = TextEditingController();

  GoogleMapController? _mapController;
  VehicleType _selectedVehicle = VehicleType.car;

  LatLng? _currentLocation;
  LatLng? _dropoffLatLng;
  bool _loadingLocation = true;

  String? _activeRideId;
  RideRequest? _activeRide;
  StreamSubscription<RideRequest>? _rideSubscription;
  bool _isRequesting = false;
  bool _isCancelling = false;

  static const _fallbackLocation = LatLng(37.42796133580664, -122.085749655962);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController?.dispose();
    _rideSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
          _pickupController.text = 'Location permission required';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      final latLng = LatLng(position.latitude, position.longitude);
      final pickupAddress = await _addressFromLatLng(latLng);

      if (!mounted) return;
      setState(() {
        _currentLocation = latLng;
        _loadingLocation = false;
        _pickupController.text = pickupAddress;
      });

      await _moveCamera(latLng);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      final latLng =
          last == null
              ? _fallbackLocation
              : LatLng(last.latitude, last.longitude);
      final fallbackAddress = await _addressFromLatLng(latLng);

      if (!mounted) return;
      setState(() {
        _currentLocation = latLng;
        _loadingLocation = false;
        _pickupController.text = fallbackAddress;
      });

      await _moveCamera(latLng);

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

  Future<String> _addressFromLatLng(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      final place = placemarks.first;
      final parts =
          [place.name, place.locality, place.administrativeArea]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      if (parts.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      return parts.join(', ');
    } catch (_) {
      return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
  }

  Future<bool> _resolveDropoffFromText() async {
    final query = _dropoffController.text.trim();
    if (query.isEmpty) return false;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return false;
      final target = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      final resolvedAddress = await _addressFromLatLng(target);

      if (!mounted) return false;
      setState(() {
        _dropoffLatLng = target;
        _dropoffController.text = resolvedAddress;
      });

      await _moveCamera(target);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that dropoff location.')),
      );
      return false;
    }
  }

  Future<void> _onMapTapped(LatLng point) async {
    if (_hasActiveRide) return;
    final address = await _addressFromLatLng(point);
    if (!mounted) return;
    setState(() {
      _dropoffLatLng = point;
      _dropoffController.text = address;
    });
  }

  Future<void> _moveCamera(LatLng target) async {
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
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

  double get _distanceKm {
    if (_currentLocation != null && _dropoffLatLng != null) {
      return _haversineKm(_currentLocation!, _dropoffLatLng!);
    }
    return 5.0;
  }

  double _fareFor(VehicleType type) {
    const baseFare = 3.25;
    const perKm = 1.15;
    return (baseFare + (_distanceKm * perKm)) * type.multiplier;
  }

  void _startWatchingRide(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _rideRepository
        .watchRide(rideId)
        .listen(
          (ride) {
            if (!mounted) return;
            setState(() => _activeRide = ride);

            final statusMsg = switch (ride.status) {
              RideStatus.accepted => 'Driver accepted your ride.',
              RideStatus.inProgress => 'Your ride is in progress.',
              RideStatus.completed => 'Ride completed.',
              RideStatus.cancelled => 'Ride cancelled.',
              _ => null,
            };

            if (statusMsg != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(statusMsg)));
            }

            if (ride.status == RideStatus.completed ||
                ride.status == RideStatus.cancelled) {
              _rideSubscription?.cancel();
              setState(() {
                _activeRideId = null;
                _activeRide = null;
              });
            }
          },
          onError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ride tracking failed: $error')),
            );
          },
        );
  }

  Future<void> _requestRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_dropoffController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a dropoff location.')),
      );
      return;
    }

    if (_dropoffLatLng == null) {
      final ok = await _resolveDropoffFromText();
      if (!ok) return;
    }

    setState(() => _isRequesting = true);
    try {
      final request = RideRequest(
        id: '',
        customerId: user.uid,
        riderId: null,
        pickup: _pickupController.text.trim(),
        dropoff: _dropoffController.text.trim(),
        status: RideStatus.requested,
        vehicleType: _selectedVehicle,
        estimatedFare: _fareFor(_selectedVehicle),
        distanceKm: _distanceKm,
        createdAt: null,
      );

      final rideId = await _rideRepository.requestRide(request);

      if (!mounted) return;
      setState(() => _activeRideId = rideId);
      _startWatchingRide(rideId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedVehicle.label} requested. Est. \$${_fareFor(_selectedVehicle).toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request ride: $error')));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _cancelRide() async {
    if (_activeRideId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel ride?'),
            content: const Text(
              'Do you want to cancel your current ride request?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancel ride'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await _rideRepository.cancelRide(_activeRideId!);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel ride: $error')));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  bool get _hasActiveRide => _activeRideId != null;

  String get _statusLabel {
    return switch (_activeRide?.status) {
      RideStatus.requested => 'Waiting for a driver...',
      RideStatus.accepted => 'Driver is on the way.',
      RideStatus.inProgress => 'Ride in progress.',
      RideStatus.completed => 'Ride completed.',
      RideStatus.cancelled => 'Ride cancelled.',
      _ => '',
    };
  }

  Color _statusColor(ThemeData theme) {
    return switch (_activeRide?.status) {
      RideStatus.accepted => Colors.green,
      RideStatus.inProgress => theme.colorScheme.primary,
      RideStatus.cancelled => theme.colorScheme.error,
      _ => theme.colorScheme.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _currentLocation ?? _fallbackLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Ride'),
        actions: [
          IconButton(
            onPressed:
                (_isRequesting || _hasActiveRide)
                    ? null
                    : _authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: mapCenter,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_currentLocation != null) {
                        _moveCamera(_currentLocation!);
                      }
                    },
                    onTap: _onMapTapped,
                    myLocationEnabled: _currentLocation != null,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: mapCenter,
                        infoWindow: const InfoWindow(title: 'Pickup'),
                      ),
                      if (_dropoffLatLng != null)
                        Marker(
                          markerId: const MarkerId('dropoff'),
                          position: _dropoffLatLng!,
                          infoWindow: const InfoWindow(title: 'Dropoff'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingLocation)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_hasActiveRide) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: _statusColor(theme).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(theme), width: 1.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (_activeRide?.status == RideStatus.requested ||
                          _activeRide?.status == RideStatus.accepted)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _statusColor(theme),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _statusColor(theme),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: RideLocationFields(
                    pickupController: _pickupController,
                    dropoffController: _dropoffController,
                    enabled: !_hasActiveRide,
                    onUseCurrentLocation: _initLocation,
                    onDropoffSubmitted: (_) => _resolveDropoffFromText(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_hasActiveRide) ...[
                Text('Choose vehicle', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...VehicleType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: VehicleOptionCard(
                      type: type,
                      selected: type == _selectedVehicle,
                      fare: _fareFor(type),
                      onTap: () => setState(() => _selectedVehicle = type),
                    ),
                  ),
                ),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dropoffLatLng != null
                            ? 'Distance: ${_distanceKm.toStringAsFixed(1)} km'
                            : 'Est. distance: ~${_distanceKm.toStringAsFixed(1)} km',
                      ),
                      Text(
                        'Est. \$${_fareFor(_selectedVehicle).toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child:
            _hasActiveRide
                ? FilledButton.icon(
                  onPressed:
                      (_isCancelling ||
                              _activeRide?.status == RideStatus.inProgress)
                          ? null
                          : _cancelRide,
                  icon:
                      _isCancelling
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.cancel_outlined),
                  label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Ride'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
                : FilledButton.icon(
                  onPressed:
                      (_isRequesting || _loadingLocation) ? null : _requestRide,
                  icon: const Icon(Icons.local_taxi),
                  label: Text(
                    _isRequesting
                        ? 'Requesting...'
                        : 'Request ${_selectedVehicle.label}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
      ),
    );
  }
}
