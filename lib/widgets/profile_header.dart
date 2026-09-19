import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircleAvatar(
                radius: 42,
                backgroundColor: AppPalette.navy,
                child: Icon(Icons.person, color: Colors.white, size: 42)),
            const SizedBox(height: 12),
            Text(user.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            Text('${user.role} • Since ${user.memberSince}',
                style: const TextStyle(color: AppPalette.muted)),
            const SizedBox(height: 12),
            FilledButton.tonal(
                onPressed: () {}, child: const Text('Edit Profile')),
          ],
        ),
      ),
    );
  }
}
