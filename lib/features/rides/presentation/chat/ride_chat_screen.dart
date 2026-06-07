import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/encryption_service.dart';
import '../../data/ride_key_manager.dart';
import '../../data/ride_repository.dart';
import '../../domain/ride_message.dart';
import '../../domain/ride_request.dart';
import '../widgets/participant_info_card.dart';

class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _rideRepo = RideRepository();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return StreamBuilder<RideRequest>(
      stream: _rideRepo.watchRide(widget.rideId),
      builder: (context, rideSnap) {
        final ride = rideSnap.data;
        if (ride == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isCustomer = user.uid == ride.customerId;
        final isRider = user.uid == ride.riderId;
        if (!isCustomer && !isRider) {
          return const Scaffold(
            body: Center(child: Text('You are not part of this ride.')),
          );
        }

        final userRole = isCustomer ? 'customer' : 'rider';
        final counterpart = isCustomer ? ride.riderInfo : ride.customerInfo;
        final counterpartLabel = isCustomer ? 'Your driver' : 'Your customer';
        final canMessage = ride.canMessage;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counterpart?.fullName ?? counterpartLabel),
                Text(
                  _statusLabel(ride.status),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: null,
                tooltip: 'Voice calls coming soon',
                icon: const Icon(Icons.call_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              if (counterpart != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ParticipantInfoCard(
                    info: counterpart,
                    roleLabel: counterpartLabel,
                    compact: true,
                  ),
                ),
              if (!canMessage)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Messaging unlocks once the ride is booked.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<RideMessage>>(
                  stream: _rideRepo.watchMessages(widget.rideId),
                  builder: (context, snap) {
                    final msgs = snap.data ?? [];
                    if (msgs.isEmpty) {
                      return const Center(child: Text('No messages yet.'));
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: msgs[i],
                        rideId: widget.rideId,
                        userRole: userRole,
                        isMine: msgs[i].senderRole == userRole,
                      ),
                    );
                  },
                ),
              ),
              if (canMessage) _buildInput(userRole),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput(String userRole) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                decoration: InputDecoration(
                  hintText: userRole == 'customer'
                      ? 'Message driver…'
                      : 'Message customer…',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E2235)
                      : const Color(0xFFF8F9FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(userRole),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _sendMessage(userRole),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String userRole) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _messageCtrl.text.trim();
    if (user == null || text.isEmpty) return;

    try {
      _messageCtrl.clear();
      final encryptionService = EncryptionService();
      final masterKey = encryptionService.deriveKeyFromPassword(user.uid);
      final rideKey = await RideKeyManager().getRideMessageKey(
        rideId: widget.rideId,
        userId: user.uid,
        userRole: userRole,
        masterKey: masterKey,
      );

      await _rideRepo.sendMessage(
        rideId: widget.rideId,
        senderId: user.uid,
        senderRole: userRole,
        text: text,
        rideKey: rideKey,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  String _statusLabel(RideStatus status) => switch (status) {
    RideStatus.requested => 'Searching for driver',
    RideStatus.booked => 'Driver booked',
    RideStatus.arrived => 'Driver arrived',
    RideStatus.inProgress => 'Ride in progress',
    RideStatus.completed => 'Ride completed',
    RideStatus.cancelled => 'Ride cancelled',
  };
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.rideId,
    required this.userRole,
    required this.isMine,
  });

  final RideMessage message;
  final String rideId;
  final String userRole;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _bubble(context, '[Error]', isMine, isDark, theme);
    }

    final encryptionService = EncryptionService();
    final masterKey = encryptionService.deriveKeyFromPassword(user.uid);

    return FutureBuilder<String>(
      future: RideKeyManager()
          .getRideMessageKey(
            rideId: rideId,
            userId: user.uid,
            userRole: userRole,
            masterKey: masterKey,
          )
          .then(
            (rideKey) =>
                encryptionService.decrypt(message.encryptedText, rideKey),
          ),
      builder: (context, snap) {
        String text = '[Decrypting...]';
        if (snap.connectionState == ConnectionState.done) {
          text = snap.hasError
              ? '[Decryption failed]'
              : (snap.data ?? '[Unknown error]');
        }
        return _bubble(context, text, isMine, isDark, theme);
      },
    );
  }

  Widget _bubble(
    BuildContext context,
    String text,
    bool isMine,
    bool isDark,
    ThemeData theme,
  ) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? theme.colorScheme.primary.withOpacity(0.15)
              : (isDark ? const Color(0xFF252A3A) : const Color(0xFFECEFF7)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14)),
      ),
    );
  }
}
