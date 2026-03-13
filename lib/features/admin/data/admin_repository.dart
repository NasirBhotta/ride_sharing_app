import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ride_sharing_app/features/auth/domain/user.dart';
import 'package:ride_sharing_app/features/rides/domain/ride_request.dart';
import 'package:ride_sharing_app/features/rides/domain/vehicle_type.dart';
import 'package:ride_sharing_app/features/role/domain/user_role.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<int> getActiveRidesCount() {
    return _firestore
        .collection('rides')
        .where('status',
            whereIn: [RideStatus.booked.name, RideStatus.inProgress.name])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getAvailableRidersCount() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.rider.value)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<double> getTodayRevenue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.completed.name)
        .where('createdAt', isGreaterThanOrEqualTo: today)
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['estimatedFare'] as num?)?.toDouble() ?? 0;
      }
      return total;
    });
  }

  Stream<Map<VehicleType, int>> watchRideMix() {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.completed.name)
        .snapshots()
        .map((snapshot) {
      final mix = <VehicleType, int>{};
      for (final doc in snapshot.docs) {
        final ride = RideRequest.fromDoc(doc);
        mix.update(ride.vehicleType, (value) => value + 1, ifAbsent: () => 1);
      }
      return mix;
    });
  }

  Stream<Map<String, double>> watchRevenueByCity() {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.completed.name)
        .snapshots()
        .map((snapshot) {
      final revenueByCity = <String, double>{};
      for (final doc in snapshot.docs) {
        final ride = RideRequest.fromDoc(doc);
        final city = ride.pickup.split(',').first.trim();
        revenueByCity.update(
            city, (value) => value + ride.estimatedFare,
            ifAbsent: () => ride.estimatedFare);
      }
      return revenueByCity;
    });
  }


  Stream<Map<String, AppUser>> watchCustomersAndRiders() {
    return _firestore
        .collection('users')
        .where('role', whereIn: [UserRole.customer.value, UserRole.rider.value])
        .snapshots()
        .map((snapshot) {
      final users = <String, AppUser>{};
      for (final doc in snapshot.docs) {
        users[doc.id] = AppUser.fromDoc(doc);
      }
      return users;
    });
  }



  Stream<List<RideRequest>> watchAllRides({int limit = 50}) {
    return _firestore
        .collection('rides')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromDoc(doc))
            .toList(growable: false));
  }

  Stream<List<AppUser>> watchUsersByRole(UserRole role, {int limit = 50}) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.value)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromDoc(doc))
            .toList(growable: false));
  }



  Stream<List<RideRequest>> watchCompletedRides({int limit = 50}) {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.completed.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromDoc(doc))
            .toList(growable: false));
  }


  Stream<List<RideRequest>> watchRecentRides() {
    return _firestore
        .collection('rides')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromDoc(doc))
            .toList(growable: false));
  }
}

