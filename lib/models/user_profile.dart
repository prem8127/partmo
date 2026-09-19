import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.role,
    required this.vehicle,
    required this.memberSince,
    this.photoBytes,
    this.photoUrl,
    this.email,
    this.phone,
  });

  final String name;
  final String role;
  final String vehicle;
  final String memberSince;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? email;
  final String? phone;

  UserProfile copyWith({
    String? name,
    String? role,
    String? vehicle,
    String? memberSince,
    Uint8List? photoBytes,
    String? photoUrl,
    String? email,
    String? phone,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      vehicle: vehicle ?? this.vehicle,
      memberSince: memberSince ?? this.memberSince,
      photoBytes: photoBytes ?? this.photoBytes,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}
