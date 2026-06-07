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

        if (_hasRide && _activeRide?.riderInfo != null) ...[
          const SizedBox(height: 12),
          ParticipantInfoCard(
            info: _activeRide!.riderInfo!,
            roleLabel: 'Your driver',
          ),
        ],

        if (_hasRide && _activeRide?.canMessage == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Open messages'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
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

}
