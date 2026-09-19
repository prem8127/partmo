import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';

class GarageState {
  const GarageState({required this.vehicles, required this.primaryId});

  final List<Vehicle> vehicles;
  final String? primaryId;

  Vehicle? get primary => vehicles.isEmpty
      ? null
      : vehicles.firstWhere(
          (v) => v.id == primaryId,
          orElse: () => vehicles.first,
        );

  GarageState copyWith({List<Vehicle>? vehicles, String? primaryId}) {
    return GarageState(
      vehicles: vehicles ?? this.vehicles,
      primaryId: primaryId ?? this.primaryId,
    );
  }
}

class GarageNotifier extends StateNotifier<GarageState> {
  GarageNotifier()
      : super(const GarageState(
          vehicles: [],
          primaryId: null,
        ));

  void addVehicle(
      {required String type, required String makeModel, required String year}) {
    final id = 'v${DateTime.now().millisecondsSinceEpoch}';
    final vehicle =
        Vehicle(id: id, type: type, makeModel: makeModel, year: year);
    state = state.copyWith(
      vehicles: [...state.vehicles, vehicle],
      primaryId: state.primaryId ?? id,
    );
  }

  void setPrimary(String id) {
    state = state.copyWith(primaryId: id);
  }

  void removeVehicle(String id) {
    final updated = state.vehicles.where((v) => v.id != id).toList();
    final newPrimary = state.primaryId == id
        ? (updated.isEmpty ? null : updated.first.id)
        : state.primaryId;
    state = GarageState(vehicles: updated, primaryId: newPrimary);
  }

  void setVehiclePhoto(String id, Uint8List bytes) {
    state = state.copyWith(
      vehicles: [
        for (final v in state.vehicles)
          v.id == id ? v.copyWith(photoBytes: bytes) : v,
      ],
    );
  }
}

final garageProvider = StateNotifierProvider<GarageNotifier, GarageState>(
  (ref) => GarageNotifier(),
);
