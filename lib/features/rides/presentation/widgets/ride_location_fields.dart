import 'package:flutter/material.dart';

class RideLocationFields extends StatelessWidget {
  const RideLocationFields({
    super.key,
    required this.pickupController,
    required this.dropoffController,
    this.onUseCurrentLocation,
    this.onDropoffSubmitted,
    this.enabled = true,
  });

  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<String>? onDropoffSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: pickupController,
          readOnly: true,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'Pickup location',
            prefixIcon: const Icon(Icons.my_location),
            suffixIcon: IconButton(
              onPressed: enabled ? onUseCurrentLocation : null,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh pickup',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: dropoffController,
          enabled: enabled,
          textInputAction: TextInputAction.search,
          onSubmitted: onDropoffSubmitted,
          decoration: const InputDecoration(
            labelText: 'Dropoff location',
            hintText: 'Enter address or tap on map',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
      ],
    );
  }
}
