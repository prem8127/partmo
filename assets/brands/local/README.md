Local / aftermarket brand logos shown when the user taps "Aftermarket & Local Brands"
under the Brands we Trust section on Home.

Add files here and then add a matching entry in the `_localBrands` list inside
lib/features/home/home_screen.dart (search for "_LocalBrandsSheet"). Use a short filename,
e.g. assets/brands/local/mybrand.png, and reference it in the list alongside the display name.

Until you add photos, each tile falls back to a generic storefront icon so the sheet still works.
