import 'dart:typed_data';

class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.makeModel,
    required this.year,
    this.vin = 'N/A',
    this.lastService = 'N/A',
    this.photoBytes,
  });

  final String id;
  final String type;
  final String makeModel;
  final String year;
  final String vin;
  final String lastService;
  final Uint8List? photoBytes;

  Vehicle copyWith({
    String? type,
    String? makeModel,
    String? year,
    String? vin,
    String? lastService,
    Uint8List? photoBytes,
  }) {
    return Vehicle(
      id: id,
      type: type ?? this.type,
      makeModel: makeModel ?? this.makeModel,
      year: year ?? this.year,
      vin: vin ?? this.vin,
      lastService: lastService ?? this.lastService,
      photoBytes: photoBytes ?? this.photoBytes,
    );
  }
}
