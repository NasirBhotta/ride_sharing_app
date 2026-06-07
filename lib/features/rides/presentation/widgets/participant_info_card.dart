import 'package:flutter/material.dart';

import '../../domain/ride_participant_info.dart';

class ParticipantInfoCard extends StatelessWidget {
  const ParticipantInfoCard({
    super.key,
    required this.info,
    required this.roleLabel,
    this.compact = false,
  });

  final RideParticipantInfo info;
  final String roleLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 18 : 22,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
            child: Icon(
              info.isRider ? Icons.local_taxi_rounded : Icons.person_rounded,
              color: theme.colorScheme.primary,
              size: compact ? 18 : 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF8B93A7)
                        : const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  info.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact && info.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    info.phone!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (!compact && info.isRider && info.vehicleModel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _vehicleLine(info),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleLine(RideParticipantInfo info) {
    final parts = <String>[
      if (info.vehicleColor != null) info.vehicleColor!,
      if (info.vehicleModel != null) info.vehicleModel!,
      if (info.licensePlate != null) info.licensePlate!,
    ];
    return parts.join(' · ');
  }
}
