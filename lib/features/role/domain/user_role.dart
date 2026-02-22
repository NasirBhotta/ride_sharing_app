enum UserRole { customer, rider }

extension UserRoleX on UserRole {
  String get value => this == UserRole.customer ? 'customer' : 'rider';

  String get label => this == UserRole.customer ? 'Customer' : 'Rider';

  static UserRole? fromString(String? input) {
    if (input == 'customer') return UserRole.customer;
    if (input == 'rider') return UserRole.rider;
    return null;
  }
}
