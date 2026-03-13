enum UserRole { customer, rider, admin }

extension UserRoleX on UserRole {
  String get value => switch (this) {
    UserRole.customer => 'customer',
    UserRole.rider => 'rider',
    UserRole.admin => 'admin',
  };

  String get label => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.rider => 'Rider',
    UserRole.admin => 'Admin',
  };

  static UserRole? fromString(String? input) {
    if (input == 'customer') return UserRole.customer;
    if (input == 'rider') return UserRole.rider;
    if (input == 'admin') return UserRole.admin;
    return null;
  }
}
