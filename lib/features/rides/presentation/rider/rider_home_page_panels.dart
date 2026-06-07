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
                    return _buildRiderMessageBubble(msg);
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

  Widget _buildRiderMessageBubble(RideMessage message) {
    final encryptionService = EncryptionService();
    final keyManager = RideKeyManager();
    final user = FirebaseAuth.instance.currentUser;
    final rideId = _activeRideId;
    final isRider = message.senderRole == 'rider';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (user == null || rideId == null) {
      return Align(
        alignment: isRider ? Alignment.centerRight : Alignment.centerLeft,
        child: _messageBubble('[Error decrypting]', isRider, isDark, theme),
      );
    }

    final masterKey = encryptionService.deriveKeyFromPassword(user.uid);

    return FutureBuilder<String>(
      future: keyManager
          .getRideMessageKey(
            rideId: rideId,
            userId: user.uid,
            userRole: 'rider',
            masterKey: masterKey,
          )
          .then((rideKey) => encryptionService.decrypt(message.encryptedText, rideKey)),
      builder: (ctx, snap) {
        String displayText = '[Decrypting...]';
        if (snap.connectionState == ConnectionState.done) {
          displayText = snap.hasError ? '[Decryption failed]' : (snap.data ?? '[Unknown error]');
        }
        return Align(
          alignment: isRider ? Alignment.centerRight : Alignment.centerLeft,
          child: _messageBubble(displayText, isRider, isDark, theme),
        );
      },
    );
  }

  Widget _messageBubble(String text, bool isRider, bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      decoration: BoxDecoration(
        color: isRider
            ? theme.colorScheme.primary.withOpacity(0.15)
            : (isDark ? const Color(0xFF252A3A) : const Color(0xFFECEFF7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
    );
  }

  // ── Ride request list ─────────────────────────────────────────────
}
