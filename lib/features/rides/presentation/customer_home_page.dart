import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart'; // FIX #12: voice navigation
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing_app/features/rides/presentation/direction_parser.dart';

import '../../../app/config/maps_config.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ride_repository.dart';
import '../domain/ride_message.dart';
import '../domain/ride_request.dart';
import '../domain/vehicle_type.dart';
import 'navigation_hud.dart';
import 'widgets/ride_location_fields.dart';
import 'widgets/vehicle_option_card.dart';

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

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});
  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  static const _initialRadiusKm = 2.0;
  static const _radiusStepKm = 1.0;
  static const _maxRadiusKm = 8.0;
  static const _radiusStepInterval = Duration(seconds: 30);
  static const _fallback = LatLng(37.42796133580664, -122.085749655962);

  final _rideRepo = RideRepository();
  final _authRepo = AuthRepository();
  final _pickupCtrl = TextEditingController(text: 'Detecting location...');
  final _dropoffCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  // FIX #12: TTS for voice navigation
  final FlutterTts _tts = FlutterTts();
  String? _lastSpokenInstruction;
  BitmapDescriptor? _headingIcon;

  GoogleMapController? _mapCtrl;
  VehicleType _vehicle = VehicleType.car;
  LatLng? _currentLoc;
  double _currentHeading = 0;
  LatLng? _dropoffLatLng;
  bool _loadingLoc = true;
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  // FIX #3: track closest polyline index
  int _closestPolylineIndex = 0;

  RouteInfo? _routeInfo;

  _RouteState _routeState = _RouteState.idle;
  String? _routeError;
  RideStatus? _lastRouteStatus;

  String? _activeRideId;
  RideRequest? _activeRide;
  StreamSubscription<RideRequest>? _rideSub;
  StreamSubscription<Position>? _posSub;
  Timer? _radiusTimer;
  double _searchRadiusKm = _initialRadiusKm;

  bool _isRequesting = false;
  bool _isCancelling = false;

  // ── Lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initTts();
    _loadHeadingIcon();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _loadHeadingIcon() async {
    final icon = await _buildHeadingIcon();
    if (!mounted) return;
    setState(() => _headingIcon = icon);
  }

  Future<BitmapDescriptor> _buildHeadingIcon() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fill = Paint()..color = const Color(0xFF1A6BFF);
    final stroke =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;
    final path =
        Path()
          ..moveTo(size / 2, 6)
          ..lineTo(size - 8, size - 10)
          ..lineTo(size / 2, size - 28)
          ..lineTo(8, size - 10)
          ..close();
    canvas.drawShadow(path, Colors.black54, 4, false);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _messageCtrl.dispose();
    _mapCtrl?.dispose();
    _rideSub?.cancel();
    _posSub?.cancel();
    _radiusTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────

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
          last == null ? _fallback : LatLng(last.latitude, last.longitude);
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

  Future<void> _updateRoute(RideRequest ride, {bool force = false}) async {
    if (ride.status != _lastRouteStatus || force) {
      // status changed → full re-fetch
    } else {
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
      if (ride.riderLat != null &&
          ride.riderLng != null &&
          ride.pickupLat != null &&
          ride.pickupLng != null) {
        origin = LatLng(ride.riderLat!, ride.riderLng!);
        dest = LatLng(ride.pickupLat!, ride.pickupLng!);
      }
    } else if (ride.status == RideStatus.inProgress) {
      final oLat = ride.customerLat ?? ride.pickupLat;
      final oLng = ride.customerLng ?? ride.pickupLng;
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
          _lastRouteStatus = ride.status;
        });
        return;
      }

      final info = RouteInfo.fromJson(res.body);
      if (info == null || info.steps.isEmpty) {
        setState(() {
          _routeState = _RouteState.emptyResult;
          _polylines = {};
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
        if (ride.status != RideStatus.inProgress) {
          unawaited(_fitBounds(origin, dest));
        }

        // FIX #12: Speak first instruction (in-progress only)
        if (info.steps.isNotEmpty &&
            ride.status == RideStatus.inProgress) {
          _speakInstruction(info.steps.first.instruction);
        }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeState = _RouteState.exception;
        _routeError = e.toString();
        _polylines = {};
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
      if (ride.riderLat != null && ride.riderLng != null)
        cur = LatLng(ride.riderLat!, ride.riderLng!);
      if (ride.pickupLat != null && ride.pickupLng != null)
        dest = LatLng(ride.pickupLat!, ride.pickupLng!);
    } else if (ride.status == RideStatus.inProgress) {
      final oLat = ride.customerLat ?? _currentLoc?.latitude;
      final oLng = ride.customerLng ?? _currentLoc?.longitude;
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

    // FIX #3: Windowed search from last known index
    final searchStart = _closestPolylineIndex;
    final searchEnd = min(searchStart + 30, _routePoints.length);

    var ci = searchStart;
    var cd = double.infinity;

    for (var i = searchStart; i < searchEnd; i++) {
      final d = _haversineKm(cur, _routePoints[i]);
      if (d < cd) {
        cd = d;
        ci = i;
      }
    }

    if (ci == searchStart && searchStart > 0) {
      for (var i = 0; i < _routePoints.length; i++) {
        final d = _haversineKm(cur, _routePoints[i]);
        if (d < cd) {
          cd = d;
          ci = i;
        }
      }
    }

    _closestPolylineIndex = ci;

    // FIX #4: Off-route detection
    if (cd * 1000 > 40) {
      unawaited(_updateRoute(ride, force: true));
      return;
    }

    if (!mounted) return;
    final theme = Theme.of(context);

    setState(() {
      // FIX #6: Full gray base route + colored remaining route
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

  // ── Distance / fare ───────────────────────────────────────────────

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
    _searchRadiusKm = _initialRadiusKm;
    _radiusTimer = Timer.periodic(_radiusStepInterval, (t) async {
      final ride = _activeRide;
      if (ride == null ||
          ride.status != RideStatus.requested ||
          _searchRadiusKm >= _maxRadiusKm) {
        t.cancel();
        return;
      }
      _searchRadiusKm = min(_searchRadiusKm + _radiusStepKm, _maxRadiusKm);
      await _rideRepo.expandSearchRadius(
        rideId: id,
        newRadiusKm: _searchRadiusKm,
        maxRadiusKm: _maxRadiusKm,
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
        searchRadiusKm: _initialRadiusKm,
        maxRadiusKm: _maxRadiusKm,
      );
      final id = await _rideRepo.requestRide(req);
      if (!mounted) return;
      setState(() {
        _activeRideId = id;
        _searchRadiusKm = _initialRadiusKm;
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

  bool get _hasRide => _activeRideId != null;

    bool get _showHUD =>
        _routeInfo != null &&
        _activeRide != null &&
        _activeRide!.status == RideStatus.inProgress;

  String get _statusLabel => switch (_activeRide?.status) {
    RideStatus.requested =>
      'Searching nearby drivers (${_searchRadiusKm.toStringAsFixed(0)} km)...',
    RideStatus.booked => 'Driver booked. On the way.',
    RideStatus.arrived => 'Driver has arrived.',
    RideStatus.inProgress => 'Ride in progress.',
    RideStatus.completed => 'Ride completed.',
    RideStatus.cancelled => 'Ride cancelled.',
    _ => '',
  };

  Color _statusColor(ThemeData t) => switch (_activeRide?.status) {
    RideStatus.booked => Colors.green,
    RideStatus.arrived => t.colorScheme.primary,
    RideStatus.inProgress => t.colorScheme.primary,
    RideStatus.cancelled => t.colorScheme.error,
    _ => t.colorScheme.secondary,
  };

  // ── Route badge ───────────────────────────────────────────────────

  Widget _routeBadge(ThemeData theme) {
    if (_routeState == _RouteState.idle || _routeState == _RouteState.success)
      return const SizedBox.shrink();
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
        Colors.orange,
        'Route coords not available yet',
      ),
      _RouteState.apiError => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
        'Directions API error',
      ),
      _RouteState.emptyResult => (
        Icons.directions_off_outlined,
        Colors.orange,
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
          _routeError == null
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
                          Text(_routeError!, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_routeError != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 13, color: color.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _currentLoc ?? _fallback;
    final riderLat = _activeRide?.riderLat;
    final riderLng = _activeRide?.riderLng;
    final isNavState =
        _activeRide?.status == RideStatus.booked ||
        _activeRide?.status == RideStatus.inProgress;
    final showPickupMarker = !isNavState;
    final showHeadingMarker =
        _activeRide?.status == RideStatus.inProgress && _currentLoc != null;
    final showRider = !_showHUD;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Ride'),
        actions: [
          IconButton(
            onPressed: (_isRequesting || _hasRide) ? null : _authRepo.signOut,
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
              // ── Map with HUD overlay ───────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: center,
                            zoom: 14,
                          ),
                          // FIX #11: Use PanGestureRecognizer
                          gestureRecognizers:
                              <Factory<OneSequenceGestureRecognizer>>{
                                Factory<PanGestureRecognizer>(
                                  () => PanGestureRecognizer(),
                                ),
                              },
                          onMapCreated: (c) {
                            _mapCtrl = c;
                            if (_currentLoc != null) _moveCamera(_currentLoc!);
                          },
                          onTap: _onMapTapped,
                            myLocationEnabled:
                                _currentLoc != null && !showHeadingMarker,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                          polylines: _polylines,
                          markers: {
                            if (showHeadingMarker)
                              Marker(
                                markerId: const MarkerId('heading'),
                                position: _currentLoc!,
                                infoWindow: const InfoWindow(title: 'Heading'),
                                rotation: _currentHeading,
                                flat: true,
                                anchor: const Offset(0.5, 0.5),
                                icon:
                                    _headingIcon ??
                                    BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueAzure,
                                    ),
                              ),
                            if (showPickupMarker)
                              Marker(
                                markerId: const MarkerId('pickup'),
                                position: center,
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
                            if (showRider &&
                                riderLat != null &&
                                riderLng != null)
                              Marker(
                                markerId: const MarkerId('rider'),
                                position: LatLng(riderLat, riderLng),
                                infoWindow: const InfoWindow(title: 'Driver'),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen,
                                ),
                              ),
                          },
                        ),
                      ),

                      // Navigation HUD
                      if (_showHUD)
                        NavigationHUD(
                          steps: _routeInfo!.steps,
                          currentPos: _currentLoc ?? center,
                          totalDistM: _routeInfo!.totalDistanceM,
                          etaSeconds: _routeInfo!.totalDurationSec,
                          rideStatus: _activeRide!.status,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_loadingLoc)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              if (_hasRide) ...[
                _routeBadge(theme),
                if (_routeState != _RouteState.idle &&
                    _routeState != _RouteState.success)
                  const SizedBox(height: 8),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: _statusColor(theme).withOpacity(0.12),
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
                          _activeRide?.status == RideStatus.booked)
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
                    pickupController: _pickupCtrl,
                    dropoffController: _dropoffCtrl,
                    enabled: !_hasRide,
                    onUseCurrentLocation: _initLocation,
                    onDropoffSubmitted: (_) => _resolveDropoff(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!_hasRide) ...[
                Text('Choose vehicle', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...VehicleType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: VehicleOptionCard(
                      type: t,
                      selected: t == _vehicle,
                      fare: _fare(t),
                      onTap: () => setState(() => _vehicle = t),
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
                            ? 'Distance: ${_distKm.toStringAsFixed(1)} km'
                            : 'Est. distance: ~${_distKm.toStringAsFixed(1)} km',
                      ),
                      // FIX #10: Removed ×50 bug — fare is already correct
                      Text(
                        'Est. PKR ${_fare(_vehicle).toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),

              if (_hasRide) ...[
                const SizedBox(height: 16),
                Text('Messages', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: StreamBuilder<List<RideMessage>>(
                    stream: _rideRepo.watchMessages(_activeRideId!),
                    builder: (ctx, snap) {
                      final msgs = snap.data ?? [];
                      if (msgs.isEmpty)
                        return const Center(child: Text('No messages yet.'));
                      return ListView.builder(
                        reverse: true,
                        itemCount: msgs.length,
                        itemBuilder:
                            (_, i) => ListTile(
                              dense: true,
                              title: Text(msgs[i].text),
                              subtitle: Text(msgs[i].senderRole),
                            ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Message driver',
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child:
            _hasRide
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
                      (_isRequesting || _loadingLoc) ? null : _requestRide,
                  icon: const Icon(Icons.local_taxi),
                  label: Text(
                    _isRequesting
                        ? 'Requesting...'
                        : 'Request ${_vehicle.label}',
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
