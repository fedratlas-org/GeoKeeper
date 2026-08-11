import 'package:flutter/material.dart';

enum PlaceCategory {
  food,
  work,
  home,
  shopping,
  attraction,
  custom;

  String get displayName {
    switch (this) {
      case PlaceCategory.food:
        return 'Food & Drink';
      case PlaceCategory.work:
        return 'Work';
      case PlaceCategory.home:
        return 'Home';
      case PlaceCategory.shopping:
        return 'Shopping';
      case PlaceCategory.attraction:
        return 'Attraction';
      case PlaceCategory.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.food:
        return Icons.restaurant;
      case PlaceCategory.work:
        return Icons.work;
      case PlaceCategory.home:
        return Icons.home;
      case PlaceCategory.shopping:
        return Icons.shopping_bag;
      case PlaceCategory.attraction:
        return Icons.attractions;
      case PlaceCategory.custom:
        return Icons.pin_drop;
    }
  }

  Color get color {
    switch (this) {
      case PlaceCategory.food:
        return const Color(0xFFFF6D00); // Vibrant orange
      case PlaceCategory.work:
        return const Color(0xFF2979FF); // Vibrant blue
      case PlaceCategory.home:
        return const Color(0xFF00E676); // Vibrant green
      case PlaceCategory.shopping:
        return const Color(0xFFAA00FF); // Purple
      case PlaceCategory.attraction:
        return const Color(0xFF00E5FF); // Cyan
      case PlaceCategory.custom:
        return const Color(0xFFFF1744); // Red/Pink
    }
  }

  /// Marker hue for Google Maps (0.0 to 360.0)
  double get markerHue {
    switch (this) {
      case PlaceCategory.food:
        return 30.0; // ORANGE
      case PlaceCategory.work:
        return 210.0; // AZURE
      case PlaceCategory.home:
        return 120.0; // GREEN
      case PlaceCategory.shopping:
        return 280.0; // VIOLET
      case PlaceCategory.attraction:
        return 180.0; // CYAN
      case PlaceCategory.custom:
        return 0.0; // RED
    }
  }
}

class SavedPlace {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final PlaceCategory category;
  final double rating;
  final bool isFavorite;
  final DateTime createdAt;
  final String? address;
  final String? imagePath;

  SavedPlace({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.rating = 5.0,
    this.isFavorite = false,
    DateTime? createdAt,
    this.address,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  SavedPlace copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    PlaceCategory? category,
    double? rating,
    bool? isFavorite,
    DateTime? createdAt,
    String? address,
    String? imagePath,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'rating': rating,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'imagePath': imagePath,
    };
  }

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: PlaceCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => PlaceCategory.custom,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      address: json['address'] as String?,
      imagePath: json['imagePath'] as String?,
    );
  }
}
