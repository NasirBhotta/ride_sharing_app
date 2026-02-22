import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  Future<void> _acceptRide(BuildContext context, String rideId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'status': 'accepted',
        'riderId': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride accepted.')));
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to accept ride: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsStream =
        FirebaseFirestore.instance
            .collection('rides')
            .where('status', isEqualTo: 'requested')
            .orderBy('createdAt', descending: true)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Home'),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load ride requests.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No ride requests right now.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final ride = docs[index].data();
              return ListTile(
                tileColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text('Pickup: ${ride['pickup'] ?? 'N/A'}'),
                subtitle: Text('Dropoff: ${ride['dropoff'] ?? 'N/A'}'),
                trailing: TextButton(
                  onPressed: () => _acceptRide(context, docs[index].id),
                  child: const Text('Accept'),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}
