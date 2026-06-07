part of 'customer_home_page.dart';

extension _CustomerHomePagePanels on _CustomerHomePageState {
  Widget _buildBottomPanelContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

        if (!_hasRide && _dropoffCtrl.text.trim().isNotEmpty) ...[
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

        if (!_hasRide && _dropoffCtrl.text.trim().isNotEmpty)
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
                  // FIX #10: Removed ?50 bug ? fare is already correct
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
                  itemBuilder: (_, i) => _buildDecryptedMessage(msgs[i]),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  decoration: const InputDecoration(hintText: 'Message driver'),
                ),
              ),
              IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
            ],
          ),
        ],

        const SizedBox(height: 12),

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
              onPressed: (_isRequesting || _loadingLoc) ? null : _requestRide,
              icon: const Icon(Icons.local_taxi),
              label: Text(
                _isRequesting ? 'Requesting...' : 'Request ${_vehicle.label}',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildDecryptedMessage(RideMessage message) {
    final encryptionService = EncryptionService();
    final keyManager = RideKeyManager();
    final user = FirebaseAuth.instance.currentUser;
    final rideId = _activeRideId;

    if (user == null || rideId == null) {
      return ListTile(
        dense: true,
        title: const Text('[Error decrypting]'),
        subtitle: Text(message.senderRole),
      );
    }

    // Derive master key from user ID (must match encryption logic)
    final masterKey = encryptionService.deriveKeyFromPassword(user.uid);

    return FutureBuilder<String>(
      future: keyManager
          .getRideMessageKey(
            rideId: rideId,
            userId: user.uid,
            userRole: 'customer',
            masterKey: masterKey,
          )
          .then((rideKey) => encryptionService.decrypt(message.encryptedText, rideKey)),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ListTile(
            dense: true,
            title: const Text('[Decrypting...]'),
            subtitle: Text(message.senderRole),
          );
        }
        if (snap.hasError) {
          return ListTile(
            dense: true,
            title: const Text('[Decryption failed]'),
            subtitle: Text(message.senderRole),
          );
        }
        final decryptedText = snap.data ?? '[Unknown error]';
        return ListTile(
          dense: true,
          title: Text(decryptedText),
          subtitle: Text(message.senderRole),
        );
      },
    );
  }
}
