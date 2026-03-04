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

enum _RouteState {
  idle,
  loading,
  success,
  noApiKey,
  missingCoords,
  apiError,
  emptyResult,
  exception,
}

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key});

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage>
    with SingleTickerProviderStateMixin {
  // ── Repos / controllers ───────────────────────────────────────────
  final _rideRepository = RideRepository();
  final _authRepository = AuthRepository();
  final _messageController = TextEditingController();

  // ── Map ───────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _loadingLocation = true;
  Set<Polyline> _polylines = {};

  // ── Route state ───────────────────────────────────────────────────
  _RouteState _routeState = _RouteState.idle;
  String? _routeErrorDetail;

  // FIX: track last status so route is only re-fetched on status change,
  // not on every rider GPS position update.
  RideStatus? _lastRouteStatus;

  // ── Ride ──────────────────────────────────────────────────────────
  String? _activeRideId;
  RideRequest? _activeRide;
  StreamSubscription<RideRequest>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;

  // ── Panel slide-in animation ──────────────────────────────────────
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;

  static const _fallbackLocation = LatLng(37.42796133580664, -122.085749655962);

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
    _initLocation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _mapController?.dispose();
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    _panelCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Location
  // ─────────────────────────────────────────────────────────────────

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
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Route drawing
  //
  // FIX 1: Route only re-fetched when ride STATUS changes, not on every
  //        GPS position update — prevents Directions API spam and UI refresh.
  // FIX 2: inProgress uses _currentLocation (live) → dropoff, with stored
  //        riderLat/riderLng as fallback. Origin is the rider's current
  //        position, not the static pickup point.
  // FIX 3: Camera bounds only set once per status transition.
  // FIX 4: arrived status explicitly clears polyline (was falling through
  //        to the else branch but only by coincidence — now explicit).
  // ─────────────────────────────────────────────────────────────────

  Future<void> _updateDirectionsForRide(
    RideRequest ride, {
    bool forceRefetch = false,
  }) async {
    // Only re-fetch when status changes to avoid hammering the API
    // and causing constant rebuilds on GPS updates.
    final statusChanged = ride.status != _lastRouteStatus;
    if (!statusChanged && !forceRefetch) {
      // Just refresh the marker; no route re-fetch needed.
      if (mounted) setState(() {});
      return;
    }

    // Guard 1: API key
    if (MapsConfig.directionsApiKey == 'YOUR_GOOGLE_DIRECTIONS_API_KEY') {
      if (mounted) {
        setState(() {
          _routeState = _RouteState.noApiKey;
          _routeErrorDetail =
              'MapsConfig.directionsApiKey is still the placeholder value. '
              'Replace it in maps_config.dart.';
          _polylines = {};
          _lastRouteStatus = ride.status;
        });
      }
      debugPrint('[RiderRoute] No API key configured.');
      return;
    }

    LatLng? origin;
    LatLng? destination;

    if (ride.status == RideStatus.booked) {
      // Rider current position → Pickup
      // Use live GPS first; fall back to stored riderLat/riderLng.
      final oLat = _currentLocation?.latitude ?? ride.riderLat;
      final oLng = _currentLocation?.longitude ?? ride.riderLng;
      if (oLat != null &&
          oLng != null &&
          ride.pickupLat != null &&
          ride.pickupLng != null) {
        origin = LatLng(oLat, oLng);
        destination = LatLng(ride.pickupLat!, ride.pickupLng!);
        debugPrint('[RiderRoute] booked  origin=$origin  dest=$destination');
      } else {
        debugPrint(
          '[RiderRoute] booked — coords missing. '
          'currentLocation=$_currentLocation '
          'riderLat=${ride.riderLat} pickupLat=${ride.pickupLat}',
        );
      }
    } else if (ride.status == RideStatus.inProgress) {
      // FIX: Origin is the rider's CURRENT live position → Dropoff.
      // This is correct: the rider is driving toward the dropoff.
      // Use _currentLocation (updated every 10m by the stream) with
      // riderLat/riderLng from Firestore as fallback.
      final oLat = _currentLocation?.latitude ?? ride.riderLat;
      final oLng = _currentLocation?.longitude ?? ride.riderLng;
      if (oLat != null &&
          oLng != null &&
          ride.dropoffLat != null &&
          ride.dropoffLng != null) {
        origin = LatLng(oLat, oLng);
        destination = LatLng(ride.dropoffLat!, ride.dropoffLng!);
        debugPrint(
          '[RiderRoute] inProgress  origin=$origin  dest=$destination',
        );
      } else {
        debugPrint(
          '[RiderRoute] inProgress — coords missing. '
          'currentLocation=$_currentLocation '
          'riderLat=${ride.riderLat} dropoffLat=${ride.dropoffLat}',
        );
      }
    } else {
      // arrived / completed / cancelled / requested → clear polyline
      debugPrint(
        '[RiderRoute] Status=${ride.status.name} — clearing polyline.',
      );
      _clearPolylines();
      if (mounted) setState(() => _lastRouteStatus = ride.status);
      return;
    }

    // Guard 2: coords resolved?
    if (origin == null || destination == null) {
      if (mounted) {
        setState(() {
          _routeState = _RouteState.missingCoords;
          _routeErrorDetail =
              'Status is ${ride.status.name} but coordinates are null.\n'
              'currentLocation=$_currentLocation\n'
              'riderLat=${ride.riderLat}  pickupLat=${ride.pickupLat}\n'
              'dropoffLat=${ride.dropoffLat}';
          _polylines = {};
          _lastRouteStatus = ride.status;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _routeState = _RouteState.loading;
        _lastRouteStatus = ride.status;
      });
    }

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
    } catch (e, st) {
      debugPrint('[RiderRoute] Exception: $e\n$st');
      if (!mounted) return;
      setState(() {
        _routeState = _RouteState.exception;
        _routeErrorDetail = e.toString();
        _polylines = {};
      });
      return;
    }

    if (!mounted) return;

    // Guard 3: API error message
    if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
      debugPrint('[RiderRoute] API error: ${result.errorMessage}');
      setState(() {
        _routeState = _RouteState.apiError;
        _routeErrorDetail = result.errorMessage;
        _polylines = {};
      });
      return;
    }

    // Guard 4: empty points
    if (result.points.isEmpty) {
      debugPrint(
        '[RiderRoute] 0 points returned. '
        'origin=$origin  destination=$destination',
      );
      setState(() {
        _routeState = _RouteState.emptyResult;
        _routeErrorDetail =
            'Directions API returned no route points.\n'
            'origin: $origin\ndestination: $destination\n'
            'Ensure the Directions API is enabled for your key.';
        _polylines = {};
      });
      return;
    }

    debugPrint('[RiderRoute] ${result.points.length} points drawn.');

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
      _routeState = _RouteState.success;
      _routeErrorDetail = null;
    });

    // FIX: Only fit bounds on the status-change fetch, not on every GPS tick.
    unawaited(_fitMapToBounds(origin, destination));
  }

  void _clearPolylines() {
    if (_polylines.isNotEmpty || _routeState != _RouteState.idle) {
      if (mounted) {
        setState(() {
          _polylines = {};
          _routeState = _RouteState.idle;
          _routeErrorDetail = null;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Distance helpers
  // ─────────────────────────────────────────────────────────────────

  double _toRad(double d) => d * pi / 180;

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final h =
        pow(sin(dLat / 2), 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  double? _distanceToRideKm(RideRequest ride) {
    if (_currentLocation == null ||
        ride.pickupLat == null ||
        ride.pickupLng == null)
      return null;
    return _haversineKm(
      _currentLocation!,
      LatLng(ride.pickupLat!, ride.pickupLng!),
    );
  }

  bool _withinRadius(RideRequest ride) {
    final d = _distanceToRideKm(ride);
    return d != null && d <= ride.searchRadiusKm;
  }

  // ─────────────────────────────────────────────────────────────────
  // Ride actions
  // ─────────────────────────────────────────────────────────────────

  Future<void> _acceptRide(String rideId) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;
    try {
      await _rideRepository.acceptRide(rideId: rideId, riderId: riderId);
      if (!mounted) return;
      setState(() => _activeRideId = rideId);
      _startWatchingRide(rideId);
      _startRiderLocationUpdates(rideId);
      _panelCtrl.forward();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride accepted!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept: $error')));
    }
  }

  Future<void> _markArrived() async {
    if (_activeRideId == null) return;
    await _rideRepository.markArrived(_activeRideId!);
    // Polyline will be cleared by the stream when status updates to arrived.
    // No need to call _clearPolylines() here — avoid double-setState.
  }

  Future<void> _startRide() async {
    if (_activeRideId == null) return;
    await _rideRepository.startRide(_activeRideId!);
    // Route will be drawn by the stream when status updates to inProgress.
  }

  Future<void> _completeRide() async {
    if (_activeRideId == null) return;
    await _rideRepository.completeRide(_activeRideId!);
    // Polyline will be cleared by the stream when status updates to completed.
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

  void _startWatchingRide(String rideId) {
    _rideSubscription?.cancel();
    _lastRouteStatus = null; // reset so first event always draws route

    _rideSubscription = _rideRepository.watchRide(rideId).listen((ride) {
      if (!mounted) return;

      final previousStatus = _activeRide?.status;
      setState(() => _activeRide = ride);

      // FIX: _updateDirectionsForRide now guards against re-fetching on every
      // GPS update — only refetches the route when status actually changes.
      unawaited(_updateDirectionsForRide(ride));

      // FIX: Only fit camera to customer↔rider when status first transitions
      // to booked — not on every subsequent GPS update which caused constant
      // camera jumps and UI refreshes.
      if (ride.status == RideStatus.booked &&
          ride.status != previousStatus &&
          _currentLocation != null &&
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
        _clearPolylines();
        _panelCtrl.reverse();
        setState(() {
          _activeRideId = null;
          _activeRide = null;
          _lastRouteStatus = null;
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
      // FIX: Do NOT call setState here. The Firestore stream will fire when
      // riderLat/riderLng update on the document, which will call setState
      // via _startWatchingRide. Calling setState here too caused double
      // refreshes on every GPS ping.
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // Computed helpers
  // ─────────────────────────────────────────────────────────────────

  bool get _hasActiveRide => _activeRideId != null;

  String get _statusLabel => switch (_activeRide?.status) {
    RideStatus.booked => 'Navigate to pickup',
    RideStatus.arrived => 'Waiting at pickup',
    RideStatus.inProgress => 'Ride in progress',
    RideStatus.completed => 'Ride completed',
    _ => '',
  };

  (Color, IconData) _statusStyle(ThemeData theme) => switch (_activeRide
      ?.status) {
    RideStatus.booked => (theme.colorScheme.primary, Icons.navigation_rounded),
    RideStatus.arrived => (
      const Color(0xFF15BA78),
      Icons.where_to_vote_rounded,
    ),
    RideStatus.inProgress => (const Color(0xFFFF8C00), Icons.drive_eta_rounded),
    RideStatus.completed => (
      const Color(0xFF15BA78),
      Icons.check_circle_rounded,
    ),
    _ => (theme.colorScheme.secondary, Icons.info_outline_rounded),
  };

  bool get _canMarkArrived => _activeRide?.status == RideStatus.booked;
  bool get _canStartRide => _activeRide?.status == RideStatus.arrived;
  bool get _canComplete => _activeRide?.status == RideStatus.inProgress;

  // ─────────────────────────────────────────────────────────────────
  // Route badge
  // ─────────────────────────────────────────────────────────────────

  Widget _buildRouteBadge(ThemeData theme) {
    if (_routeState == _RouteState.idle || _routeState == _RouteState.success) {
      return const SizedBox.shrink();
    }

    final (icon, color, label) = switch (_routeState) {
      _RouteState.loading => (
        Icons.route_outlined,
        theme.colorScheme.primary,
        'Loading route…',
      ),
      _RouteState.noApiKey => (
        Icons.vpn_key_off_outlined,
        theme.colorScheme.error,
        'Directions API key not set',
      ),
      _RouteState.missingCoords => (
        Icons.location_off_outlined,
        const Color(0xFFFF8C00),
        'Route coords unavailable',
      ),
      _RouteState.apiError => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        'Directions API error',
      ),
      _RouteState.emptyResult => (
        Icons.directions_off_outlined,
        const Color(0xFFFF8C00),
        'No driveable route found',
      ),
      _RouteState.exception => (
        Icons.error_outline,
        theme.colorScheme.error,
        'Route fetch failed',
      ),
      _ => (Icons.info_outline, theme.colorScheme.secondary, ''),
    };

    return GestureDetector(
      onTap:
          _routeErrorDetail == null
              ? null
              : () => showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder:
                    (_) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Route diagnostic',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _routeErrorDetail!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_routeErrorDetail != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: color.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mapCenter = _currentLocation ?? _fallbackLocation;
    final customerLat = _activeRide?.customerLat ?? _activeRide?.pickupLat;
    final customerLng = _activeRide?.customerLng ?? _activeRide?.pickupLng;
    final (statusColor, statusIcon) = _statusStyle(theme);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _hasActiveRide
                        ? const Color(0xFF15BA78)
                        : (isDark
                            ? const Color(0xFF8B93A7)
                            : const Color(0xFF9CA3AF)),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Driver Dashboard'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _authRepository.signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Map ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                    zoomControlsEnabled: false,
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
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                    },
                  ),
                ),
              ),
            ),

            // ── Progress indicators ──────────────────────────────
            if (_loadingLocation)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_routeState == _RouteState.loading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.colorScheme.primary,
                ),
              ),

            // ── Route badge ──────────────────────────────────────
            if (_hasActiveRide)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildRouteBadge(theme),
                ),
              ),

            const SizedBox(height: 6),

            // ── Content ──────────────────────────────────────────
            Expanded(
              child:
                  _hasActiveRide
                      ? SlideTransition(
                        position: _panelSlide,
                        child: _buildActiveRidePanel(
                          theme,
                          isDark,
                          statusColor,
                          statusIcon,
                        ),
                      )
                      : _buildRideList(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Active ride panel
  // ─────────────────────────────────────────────────────────────────

  Widget _buildActiveRidePanel(
    ThemeData theme,
    bool isDark,
    Color statusColor,
    IconData statusIcon,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: statusColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_activeRide != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_activeRide!.pickup} → ${_activeRide!.dropoff}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor.withOpacity(0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_activeRide != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_activeRide!.estimatedFare.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'est. fare',
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Arrived',
                  icon: Icons.where_to_vote_rounded,
                  enabled: _canMarkArrived,
                  color: const Color(0xFF15BA78),
                  onTap: _markArrived,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  enabled: _canStartRide,
                  color: theme.colorScheme.primary,
                  onTap: _startRide,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Complete',
                  icon: Icons.flag_rounded,
                  enabled: _canComplete,
                  color: const Color(0xFFFF8C00),
                  onTap: _completeRide,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ride detail rows
          if (_activeRide != null) ...[
            _InfoRow(
              icon: Icons.my_location_rounded,
              color: const Color(0xFF15BA78),
              label: 'Pickup',
              value: _activeRide!.pickup,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_on_rounded,
              color: theme.colorScheme.primary,
              label: 'Dropoff',
              value: _activeRide!.dropoff,
            ),
            const SizedBox(height: 16),
          ],

          // Messages header
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color:
                    isDark ? const Color(0xFF8B93A7) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text('Messages', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),

          // Message list
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: StreamBuilder<List<RideMessage>>(
                stream: _rideRepository.watchMessages(_activeRideId!),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isRider = msg.senderRole == 'rider';
                      return Align(
                        alignment:
                            isRider
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isRider
                                    ? theme.colorScheme.primary.withOpacity(
                                      0.15,
                                    )
                                    : (isDark
                                        ? const Color(0xFF252A3A)
                                        : const Color(0xFFECEFF7)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg.text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2235) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF2D3348) : const Color(0xFFDDE1ED),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message customer…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(
                        color:
                            isDark
                                ? const Color(0xFF8B93A7)
                                : const Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Ride request list
  // ─────────────────────────────────────────────────────────────────

  Widget _buildRideList(ThemeData theme, bool isDark) {
    return StreamBuilder<List<RideRequest>>(
      stream: _rideRepository.watchRequestedRides(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color:
                      isDark
                          ? const Color(0xFF8B93A7)
                          : const Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load ride requests.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final rides = (snapshot.data ?? [])
            .where(_withinRadius)
            .toList(growable: false);

        if (rides.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E2235)
                            : const Color(0xFFF0F3FC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 34,
                    color:
                        isDark
                            ? const Color(0xFF8B93A7)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),
                Text('No nearby requests', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'New ride requests will appear here.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ride = rides[index];
            return _RideRequestCard(
              ride: ride,
              distanceKm: _distanceToRideKm(ride),
              onAccept: () => _acceptRide(ride.id),
              isDark: isDark,
              theme: theme,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                enabled
                    ? color.withOpacity(0.12)
                    : (isDark
                        ? const Color(0xFF1E2235)
                        : const Color(0xFFF4F6FB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? color.withOpacity(0.4) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    enabled
                        ? color
                        : (isDark
                            ? const Color(0xFF8B93A7)
                            : const Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color:
                      enabled
                          ? color
                          : (isDark
                              ? const Color(0xFF8B93A7)
                              : const Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? const Color(0xFF8B93A7)
                          : const Color(0xFF9CA3AF),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({
    required this.ride,
    required this.distanceKm,
    required this.onAccept,
    required this.isDark,
    required this.theme,
  });

  final RideRequest ride;
  final double? distanceKm;
  final VoidCallback onAccept;
  final bool isDark;
  final ThemeData theme;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.ride.vehicleType) {
    VehicleType.bike => const Color(0xFF15BA78),
    VehicleType.car => const Color(0xFF1A6BFF),
    VehicleType.premium => const Color(0xFFAA7BFF),
  };

  IconData get _icon => switch (widget.ride.vehicleType) {
    VehicleType.bike => Icons.two_wheeler_rounded,
    VehicleType.car => Icons.local_taxi_rounded,
    VehicleType.premium => Icons.directions_car_filled_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final isDark = widget.isDark;
    final theme = widget.theme;
    final ride = widget.ride;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C26) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride.vehicleType.label} ride',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 12,
                            color:
                                isDark
                                    ? const Color(0xFF8B93A7)
                                    : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ride.distanceKm.toStringAsFixed(1)} km trip'
                            '  ·  '
                            '${widget.distanceKm?.toStringAsFixed(1) ?? '--'} km away',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${ride.estimatedFare.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'est. fare',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isDark
                                ? const Color(0xFF8B93A7)
                                : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            _RoutePreview(
              pickup: ride.pickup,
              dropoff: ride.dropoff,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: 14),

            GestureDetector(
              onTapDown: (_) => _ctrl.reverse(),
              onTapUp: (_) {
                _ctrl.forward();
                widget.onAccept();
              },
              onTapCancel: () => _ctrl.forward(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Accept ride',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({
    required this.pickup,
    required this.dropoff,
    required this.isDark,
    required this.theme,
  });

  final String pickup;
  final String dropoff;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF15BA78),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 1.5, height: 26, color: lineColor),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                dropoff,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
