import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

class UserNotifier extends StateNotifier<UserProfile> {
  UserNotifier()
      : super(const UserProfile(
          name: 'User',
          role: 'Member',
          vehicle: '',
          memberSince: '',
        ));

  void updateProfile({String? name, String? role}) {
    state = state.copyWith(name: name, role: role);
  }

  void setPhoto(Uint8List bytes) {
    state = state.copyWith(photoBytes: bytes);
  }

  void setPhotoUrl(String url) {
    state = state.copyWith(photoUrl: url);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile>(
  (ref) => UserNotifier(),
);
