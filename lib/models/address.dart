class Address {
  const Address({
    required this.id,
    required this.label,
    required this.name,
    required this.line,
    required this.city,
    required this.phone,
    this.alternatePhone = '',
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String name;
  final String line;
  final String city;
  final String phone;
  final String alternatePhone;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'line': line,
        'city': city,
        'phone': phone,
        'alternatePhone': alternatePhone,
        'isDefault': isDefault,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        name: json['name'] as String? ?? '',
        line: json['line'] as String? ?? '',
        city: json['city'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        alternatePhone: json['alternatePhone'] as String? ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
