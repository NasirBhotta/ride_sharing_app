import 'dart:async';
import 'dart:math';
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

import '../../../../app/config/maps_config.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/user_repository.dart';
import '../../data/encryption_service.dart';
import '../../data/ride_repository.dart';
import '../../domain/ride_participant_info.dart';
import '../../domain/ride_request.dart';
import '../chat/ride_chat_screen.dart';
import '../widgets/participant_info_card.dart';
import '../../domain/vehicle_type.dart';
import '../navigation_hud.dart';

part 'rider_home_page_route_state.dart';
part 'rider_home_page_widgets.dart';
part 'rider_home_page_ride_list.dart';
part 'rider_home_page_request_card.dart';
part 'rider_home_page_panels.dart';
part 'rider_home_page_ui_helpers.dart';
part 'rider_home_page_actions.dart';
part 'rider_home_page_route.dart';
part 'rider_home_page_location.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key});
  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage>
    with SingleTickerProviderStateMixin {
  final _rideRepo = RideRepository();
  final _authRepo = AuthRepository();
  final _userRepo = UserRepository();

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
    _mapCtrl?.dispose();
    _rideSub?.cancel();
    _posSub?.cancel();
    _panelCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────

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
                  initialChildSize: 0.4,
                  minChildSize: 0.4,
                  maxChildSize: 0.65,
                  builder: (context, scrollController) {
                    return Container(
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
}
