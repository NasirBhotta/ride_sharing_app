import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart'; // FIX #12: voice navigation
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
  final _rideRepo = RideRepository();
  final _authRepo = AuthRepository();
  final _messageCtrl = TextEditingController();

  // FIX #12: TTS for voice navigation
  final FlutterTts _tts = FlutterTts();
  String? _lastSpokenInstruction;
  BitmapDescriptor? _headingIcon;

  GoogleMapController? _mapCtrl;
  LatLng? _currentLoc;
  double _currentHeading = 0;
  bool _loadingLoc = true;
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  // FIX #3: track closest polyline index to avoid full scan
  int _closestPolylineIndex = 0;

  _RouteState _routeState = _RouteState.idle;
  String? _routeError;
  RideStatus? _lastRouteStatus;

  RouteInfo? _routeInfo;

  String? _activeRideId;
  RideRequest? _activeRide;
  StreamSubscription<RideRequest>? _rideSub;
  StreamSubscription<Position>? _posSub;

  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;

  static const _fallback = LatLng(37.42796133580664, -122.085749655962);

  // ── Lifecycle ─────────────────────────────────────────────────────

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
    _messageCtrl.dispose();
    _mapCtrl?.dispose();
    _rideSub?.cancel();
    _posSub?.cancel();
    _panelCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────

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
          last == null ? _fallback : LatLng(last.latitude, last.longitude);
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

  Future<void> _updateRoute(RideRequest ride, {bool force = false}) async {
    if (ride.status != _lastRouteStatus || force) {
      // proceed with re-fetch
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
      await _rideRepo.acceptRide(
        rideId: id,
        riderId: riderId,
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
      senderRole: 'rider',
      text: text,
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

  bool get _hasRide => _activeRideId != null;

  bool get _showHUD =>
      _routeInfo != null &&
      _activeRide != null &&
      (_activeRide!.status == RideStatus.booked ||
          _activeRide!.status == RideStatus.inProgress);

  String get _statusLabel => switch (_activeRide?.status) {
    RideStatus.booked => 'Navigate to pickup',
    RideStatus.arrived => 'Waiting at pickup',
    RideStatus.inProgress => 'Ride in progress',
    RideStatus.completed => 'Ride completed',
    _ => '',
  };

  (Color, IconData) _statusStyle(ThemeData t) => switch (_activeRide?.status) {
    RideStatus.booked => (t.colorScheme.primary, Icons.navigation_rounded),
    RideStatus.arrived => (
      const Color(0xFF15BA78),
      Icons.where_to_vote_rounded,
    ),
    RideStatus.inProgress => (const Color(0xFFFF8C00), Icons.drive_eta_rounded),
    RideStatus.completed => (
      const Color(0xFF15BA78),
      Icons.check_circle_rounded,
    ),
    _ => (t.colorScheme.secondary, Icons.info_outline_rounded),
  };

  bool get _canMarkArrived => _activeRide?.status == RideStatus.booked;
  bool get _canStartRide => _activeRide?.status == RideStatus.arrived;
  bool get _canComplete => _activeRide?.status == RideStatus.inProgress;

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
            if (_routeError != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: color.withOpacity(0.7)),
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
    final isDark = theme.brightness == Brightness.dark;
    final center = _currentLoc ?? _fallback;
    final ride = _activeRide;
    final showDropoff = ride?.status == RideStatus.inProgress;
    final custLat =
        showDropoff
            ? (ride?.dropoffLat ?? ride?.customerLat ?? ride?.pickupLat)
            : (ride?.customerLat ?? ride?.pickupLat);
    final custLng =
        showDropoff
            ? (ride?.dropoffLng ?? ride?.customerLng ?? ride?.pickupLng)
            : (ride?.customerLng ?? ride?.pickupLng);
    final custTitle = showDropoff ? 'Dropoff' : 'Customer';
    final showHeadingMarker =
        (_activeRide?.status == RideStatus.booked ||
            _activeRide?.status == RideStatus.inProgress) &&
        _currentLoc != null;
    final showDestinationMarker = ride?.status != RideStatus.booked;
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
                    _hasRide
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
            onPressed: _authRepo.signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapHeight = constraints.maxHeight * 0.6;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: mapHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Google Map
                          Positioned.fill(
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: center,
                                zoom: 14,
                              ),
                              // FIX #11: Use PanGestureRecognizer instead of EagerGestureRecognizer
                              gestureRecognizers:
                                  <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<PanGestureRecognizer>(
                                      () => PanGestureRecognizer(),
                                    ),
                                  },
                              onMapCreated: (c) {
                                _mapCtrl = c;
                                if (_currentLoc != null)
                                  _moveCamera(_currentLoc!);
                              },
                              myLocationEnabled:
                                  _currentLoc != null && !showHeadingMarker,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: false,
                              polylines: _polylines,
                              markers: {
                                if (showHeadingMarker)
                                  Marker(
                                    markerId: const MarkerId('heading'),
                                    position: _currentLoc!,
                                    infoWindow: const InfoWindow(
                                      title: 'Heading',
                                    ),
                                    rotation: _currentHeading,
                                    flat: true,
                                    anchor: const Offset(0.5, 0.5),
                                    icon:
                                        _headingIcon ??
                                        BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueAzure,
                                        ),
                                  )
                                else
                                  Marker(
                                    markerId: const MarkerId('rider'),
                                    position: center,
                                    infoWindow: const InfoWindow(title: 'You'),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueGreen,
                                    ),
                                  ),
                                if (showDestinationMarker &&
                                    custLat != null &&
                                    custLng != null)
                                  Marker(
                                    markerId: const MarkerId('customer'),
                                    position: LatLng(custLat, custLng),
                                    infoWindow: InfoWindow(title: custTitle),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueAzure,
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
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.2,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: _buildBottomPanelContent(
                          theme,
                          isDark,
                          statusColor,
                          statusIcon,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Active ride panel ─────────────────────────────────────────────

  Widget _buildBottomPanelContent(
    ThemeData theme,
    bool isDark,
    Color statusColor,
    IconData statusIcon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingLoc)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_routeState == _RouteState.loading)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        if (_hasRide)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _routeBadge(theme),
            ),
          ),
        const SizedBox(height: 6),
        if (_hasRide)
          SlideTransition(
            position: _panelSlide,
            child: _buildActivePanel(theme, isDark, statusColor, statusIcon),
          )
        else
          _buildRideList(theme, isDark, embedded: true),
      ],
    );
  }

  Widget _buildActivePanel(
    ThemeData theme,
    bool isDark,
    Color statusColor,
    IconData statusIcon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
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

        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: isDark ? const Color(0xFF8B93A7) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text('Messages', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          height: 160,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: StreamBuilder<List<RideMessage>>(
              stream: _rideRepo.watchMessages(_activeRideId!),
              builder: (ctx, snap) {
                final msgs = snap.data ?? [];
                if (msgs.isEmpty)
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
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
                          maxWidth: MediaQuery.of(ctx).size.width * 0.65,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isRider
                                  ? theme.colorScheme.primary.withOpacity(0.15)
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

        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2235) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2D3348) : const Color(0xFFDDE1ED),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
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
    );
  }

  // ── Ride request list ─────────────────────────────────────────────

  Widget _buildRideList(ThemeData theme, bool isDark, {bool embedded = false}) {
    return StreamBuilder<List<RideRequest>>(
      stream: _rideRepo.watchRequestedRides(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError) {
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
        final rides = (snap.data ?? [])
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
          padding:
              embedded
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(16, 8, 16, 24),
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder:
              (_, i) => _RideRequestCard(
                ride: rides[i],
                distanceKm: _distToRideKm(rides[i]),
                onAccept: () => _acceptRide(rides[i].id),
                isDark: isDark,
                theme: theme,
              ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
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
    final ride = widget.ride;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF181C26) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                widget.isDark
                    ? const Color(0xFF252A3A)
                    : const Color(0xFFE5E9F5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
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
                        style: widget.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 12,
                            color:
                                widget.isDark
                                    ? const Color(0xFF8B93A7)
                                    : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ride.distanceKm.toStringAsFixed(1)} km trip  ·  ${widget.distanceKm?.toStringAsFixed(1) ?? '--'} km away',
                            style: widget.theme.textTheme.bodySmall,
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
                      style: widget.theme.textTheme.titleMedium?.copyWith(
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
                            widget.isDark
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
              isDark: widget.isDark,
              theme: widget.theme,
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
    final line = isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5);
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
            Container(width: 1.5, height: 26, color: line),
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
