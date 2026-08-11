class ApiKeys {
  static const String googleMapsApiKey = 'AIzaSyAqE5rFoLA3Q05Fos68nfsMkZdeKAMK1As';

  static bool get hasValidKey =>
      googleMapsApiKey.isNotEmpty &&
      !googleMapsApiKey.startsWith('YOUR_');
}
