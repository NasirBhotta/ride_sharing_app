import 'dart:async';
import 'dart:math';
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

import '../../../../app/config/maps_config.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/ride_repository.dart';
import '../../data/encryption_service.dart';
import '../../data/ride_key_manager.dart';
import '../../domain/ride_message.dart';
import '../../domain/ride_request.dart';
import '../../domain/vehicle_type.dart';
import '../navigation_hud.dart';
import '../widgets/ride_location_fields.dart';
import '../widgets/vehicle_option_card.dart';

part 'customer_home_page_widgets.dart';
part 'customer_home_page_panels.dart';
part 'customer_home_page_ui_helpers.dart';
part 'customer_home_page_actions.dart';
part 'customer_home_page_route.dart';
part 'customer_home_page_location.dart';
part 'customer_home_page_route_state.dart';

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
    _dropoffCtrl.addListener(_onDropoffChanged);
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
    _dropoffCtrl.removeListener(_onDropoffChanged);
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

  void _onDropoffChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ── Location ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
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
                                if (_currentLoc != null)
                                  _moveCamera(_currentLoc!);
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
                                  ),
                                if (showPickupMarker)
                                  Marker(
                                    markerId: const MarkerId('pickup'),
                                    position: center,
                                    infoWindow: const InfoWindow(
                                      title: 'Pickup',
                                    ),
                                  ),
                                if (_dropoffLatLng != null)
                                  Marker(
                                    markerId: const MarkerId('dropoff'),
                                    position: _dropoffLatLng!,
                                    infoWindow: const InfoWindow(
                                      title: 'Dropoff',
                                    ),
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
                                    infoWindow: const InfoWindow(
                                      title: 'Driver',
                                    ),
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
                ),
                DraggableGrowingSheet(
                  // minHeight: 500,
                  // maxHeight: MediaQuery.of(context).size.height * 0.65,
                  child: _buildBottomPanelContent(Theme.of(context)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
