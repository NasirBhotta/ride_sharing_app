import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../data/ride_repository.dart';
import '../domain/ride_request.dart';
import '../domain/vehicle_type.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  Future<void> _acceptRide(BuildContext context, String rideId) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) {
      return;
    }

    try {
      await RideRepository().acceptRide(rideId: rideId, riderId: riderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride accepted.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept ride: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            onPressed: AuthRepository().signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<RideRequest>>(
        stream: RideRepository().watchRequestedRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load ride requests.'));
          }

          final rides = snapshot.data ?? [];
          if (rides.isEmpty) {
            return const Center(child: Text('No ride requests right now.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${ride.vehicleType.label} ride',
                            style: theme.textTheme.titleMedium,
                          ),
                          Chip(
                            label: Text(
                              '~\$${ride.estimatedFare.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Pickup: ${ride.pickup}'),
                      Text('Dropoff: ${ride.dropoff}'),
                      Text(
                        'Distance: ${ride.distanceKm.toStringAsFixed(1)} km',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _acceptRide(context, ride.id),
                          child: const Text('Accept ride'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
