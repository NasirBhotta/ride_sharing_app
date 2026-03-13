import 'package:flutter/material.dart';

enum VehicleType { bike, car, premium }

extension VehicleTypeX on VehicleType {
  String get id => switch (this) {
        VehicleType.bike => 'bike',
        VehicleType.car => 'car',
        VehicleType.premium => 'premium',
      };

  String get label => switch (this) {
        VehicleType.bike => 'Bike',
        VehicleType.car => 'Car',
        VehicleType.premium => 'Premium',
      };

  String get eta => switch (this) {
        VehicleType.bike => '3 min',
        VehicleType.car => '5 min',
        VehicleType.premium => '7 min',
      };

  double get multiplier => switch (this) {
        VehicleType.bike => 0.7,
        VehicleType.car => 1,
        VehicleType.premium => 1.8,
      };

  Color get color => switch (this) {
        VehicleType.bike => const Color(0xFF34D399),
        VehicleType.car => const Color(0xFF60A5FA),
        VehicleType.premium => const Color(0xFFF59E0B),
      };

  static VehicleType fromId(String raw) {
    return VehicleType.values.firstWhere(
      (type) => type.id == raw,
      orElse: () => VehicleType.car,
    );
  }
}
