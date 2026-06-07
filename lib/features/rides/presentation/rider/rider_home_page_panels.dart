part of 'rider_home_page.dart';

extension _RiderHomePagePanels on _RiderHomePageState {
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
          if (_activeRide!.customerInfo != null) ...[
            ParticipantInfoCard(
              info: _activeRide!.customerInfo!,
              roleLabel: 'Your customer',
            ),
            const SizedBox(height: 12),
          ],
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

        if (_activeRide?.canMessage == true)
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
    );
  }

  // ── Ride request list ─────────────────────────────────────────────
}
