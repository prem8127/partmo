const productCategories = <String>[
  'Engine',
  'Steering',
  'Brakes',
  'Suspension',
  'Electrical',
  'Gear Parts',
  'Axle',
  'Frames',
  'Radiator & Intercooler',
  'Automotive Fluids',
  'Fuel System',
  'Oil Seals & Rubber Parts',
  'Propeller Shaft',
  'Body Parts',
  'Clutch',
  'Wheels',
  'Filters',
  'Others',
];

String normalizedCategoryKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String canonicalProductCategory(String value) {
  final trimmed = value.trim();
  final key = normalizedCategoryKey(trimmed);
  const aliases = <String, String>{
    'break': 'Brakes',
    'breaks': 'Brakes',
    'brake': 'Brakes',
    'brakes': 'Brakes',
    'filter': 'Filters',
    'filters': 'Filters',
    'body': 'Body Parts',
    'bodypart': 'Body Parts',
    'bodyparts': 'Body Parts',
    'gear': 'Gear Parts',
    'gearpart': 'Gear Parts',
    'gearparts': 'Gear Parts',
    'propellarshaft': 'Propeller Shaft',
    'propellershaft': 'Propeller Shaft',
    'wheel': 'Wheels',
    'wheels': 'Wheels',
    'tyre': 'Wheels',
    'tyres': 'Wheels',
    'radiator': 'Radiator & Intercooler',
    'intercooler': 'Radiator & Intercooler',
    'radiatorintercooler': 'Radiator & Intercooler',
    'fluid': 'Automotive Fluids',
    'fluids': 'Automotive Fluids',
    'automotivefluid': 'Automotive Fluids',
    'automotivefluids': 'Automotive Fluids',
  };
  final alias = aliases[key];
  if (alias != null) return alias;
  for (final category in productCategories) {
    if (normalizedCategoryKey(category) == key) return category;
  }
  return trimmed.isEmpty ? 'Others' : trimmed;
}

String resolveProductCategory(String value, Iterable<String> existing) {
  final requested = canonicalProductCategory(value);
  final requestedKey = normalizedCategoryKey(requested);
  for (final category in existing) {
    final canonicalExisting = canonicalProductCategory(category);
    if (normalizedCategoryKey(canonicalExisting) == requestedKey) {
      return canonicalExisting;
    }
  }
  return requested;
}

String normalizedProductName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
