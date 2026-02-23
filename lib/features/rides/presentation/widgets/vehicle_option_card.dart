import 'package:flutter/material.dart';

import '../../domain/vehicle_type.dart';

class VehicleOptionCard extends StatelessWidget {
  const VehicleOptionCard({
    super.key,
    required this.type,
    required this.selected,
    required this.fare,
    required this.onTap,
  });

  final VehicleType type;
  final bool selected;
  final double fare;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color:
              selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                  : theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(switch (type) {
              VehicleType.bike => Icons.two_wheeler,
              VehicleType.car => Icons.local_taxi,
              VehicleType.premium => Icons.directions_car_filled,
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: theme.textTheme.titleMedium),
                  Text('ETA ${type.eta}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              '\$${fare.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
