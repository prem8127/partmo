import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/app_button.dart';

class FilterData {
  const FilterData({
    required this.vehicles,
    required this.partTypes,
    required this.availability,
    required this.priceRange,
  });

  final Set<String> vehicles;
  final Set<String> partTypes;
  final Set<String> availability;
  final RangeValues priceRange;

  bool get isEmpty =>
      vehicles.isEmpty &&
      partTypes.isEmpty &&
      availability.isEmpty &&
      priceRange.start == 0 &&
      priceRange.end == 50000;

  FilterData copyWith({
    Set<String>? vehicles,
    Set<String>? partTypes,
    Set<String>? availability,
    RangeValues? priceRange,
  }) =>
      FilterData(
        vehicles: vehicles ?? this.vehicles,
        partTypes: partTypes ?? this.partTypes,
        availability: availability ?? this.availability,
        priceRange: priceRange ?? this.priceRange,
      );
}

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, this.initial});

  final FilterData? initial;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  static const _vehicleOptions = [
    'Toyota Innova',
    'Tata Harrier',
    'Maruti Swift',
    'Hyundai Creta',
    'Mahindra Scorpio'
  ];
  static const _partTypeOptions = ['OEM', 'Aftermarket', 'Refurbished'];
  static const _availabilityOptions = [
    'In stock',
    'Same-day dispatch',
    'COD eligible'
  ];

  late Set<String> _selectedVehicles;
  late Set<String> _selectedPartTypes;
  late Set<String> _selectedAvailability;
  late RangeValues _price;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _selectedVehicles = d?.vehicles.toSet() ?? {};
    _selectedPartTypes = d?.partTypes.toSet() ?? {};
    _selectedAvailability = d?.availability.toSet() ?? {};
    _price = d?.priceRange ?? const RangeValues(0, 50000);
  }

  void _clear() => setState(() {
        _selectedVehicles = {};
        _selectedPartTypes = {};
        _selectedAvailability = {};
        _price = const RangeValues(0, 50000);
      });

  void _apply() => context.pop(FilterData(
        vehicles: _selectedVehicles,
        partTypes: _selectedPartTypes,
        availability: _selectedAvailability,
        priceRange: _price,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FilterGroup(
                title: 'Vehicle',
                options: _vehicleOptions,
                selected: _selectedVehicles,
                onChanged: (item, on) => setState(() => on
                    ? _selectedVehicles.add(item)
                    : _selectedVehicles.remove(item)),
              ),
              const SizedBox(height: 16),
              Text(
                'Price Range  \u20b9${_price.start.round()} \u2013 \u20b9${_price.end.round()}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              RangeSlider(
                values: _price,
                min: 0,
                max: 50000,
                divisions: 50,
                labels: RangeLabels('\u20b9${_price.start.round()}',
                    '\u20b9${_price.end.round()}'),
                activeColor: AppPalette.navy,
                onChanged: (v) => setState(() => _price = v),
              ),
              const SizedBox(height: 16),
              _FilterGroup(
                title: 'Part Type',
                options: _partTypeOptions,
                selected: _selectedPartTypes,
                onChanged: (item, on) => setState(() => on
                    ? _selectedPartTypes.add(item)
                    : _selectedPartTypes.remove(item)),
              ),
              const SizedBox(height: 16),
              _FilterGroup(
                title: 'Availability',
                options: _availabilityOptions,
                selected: _selectedAvailability,
                onChanged: (item, on) => setState(() => on
                    ? _selectedAvailability.add(item)
                    : _selectedAvailability.remove(item)),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
            child: Row(
              children: [
                Expanded(
                    child: AppButton(
                        label: 'Clear', secondary: true, onPressed: _clear)),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        AppButton(label: 'Apply Filters', onPressed: _apply)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final void Function(String item, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (item) => FilterChip(
                      label: Text(item),
                      selected: selected.contains(item),
                      selectedColor: AppPalette.cyan.withOpacity(.18),
                      checkmarkColor: AppPalette.navy,
                      onSelected: (on) => onChanged(item, on),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
