import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/saved_place.dart';
import 'api_service.dart';

class StorageService {
  static const String _placesKey = 'saved_places_v3';
  static final _uuid = const Uuid();
  final ApiService _apiService = ApiService();

  /// Initial sample seed data for first launch
  static List<SavedPlace> get defaultSeedPlaces {
    return [];
  }

  /// Load all saved places (Syncs with Node.js backend when online, with local cache fallback)
  Future<List<SavedPlace>> loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if backend server is available
    final isOnline = await _apiService.checkHealth();
    if (isOnline) {
      try {
        final remotePlaces = await _apiService.fetchPlaces();
        await _saveList(prefs, remotePlaces);
        return remotePlaces;
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching places from remote API: $e');
        }
      }
    }

    // Offline or fallback mode: load from SharedPreferences
    final jsonString = prefs.getString(_placesKey);
    if (jsonString == null || jsonString.isEmpty) {
      final seeds = defaultSeedPlaces;
      await _saveList(prefs, seeds);
      return seeds;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => SavedPlace.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return defaultSeedPlaces;
    }
  }

  /// Save a new place (Syncs with backend and updates local storage)
  Future<List<SavedPlace>> savePlace(SavedPlace place) async {
    final places = await loadSavedPlaces();
    final newPlace = place.id.isEmpty
        ? place.copyWith(id: _uuid.v4())
        : place;

    // Add to beginning of local list
    places.insert(0, newPlace);
    final prefs = await SharedPreferences.getInstance();
    await _saveList(prefs, places);

    // Sync with REST API backend
    try {
      await _apiService.savePlace(newPlace);
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing new place to backend database: $e');
      }
    }

    return places;
  }

  /// Update an existing place
  Future<List<SavedPlace>> updatePlace(SavedPlace updatedPlace) async {
    final places = await loadSavedPlaces();
    final index = places.indexWhere((p) => p.id == updatedPlace.id);
    if (index != -1) {
      places[index] = updatedPlace;
      final prefs = await SharedPreferences.getInstance();
      await _saveList(prefs, places);

      // Sync update to backend
      try {
        await _apiService.updatePlace(updatedPlace);
      } catch (e) {
        if (kDebugMode) {
          print('Error syncing updated place to backend database: $e');
        }
      }
    }
    return places;
  }

  /// Delete a saved place by ID
  Future<List<SavedPlace>> deletePlace(String id) async {
    final places = await loadSavedPlaces();
    places.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveList(prefs, places);

    // Sync deletion to backend
    try {
      await _apiService.deletePlace(id);
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing place deletion to backend database: $e');
      }
    }

    return places;
  }

  /// Toggle favorite status of a place
  Future<List<SavedPlace>> toggleFavorite(String id) async {
    final places = await loadSavedPlaces();
    final index = places.indexWhere((p) => p.id == id);
    if (index != -1) {
      places[index] = places[index].copyWith(
        isFavorite: !places[index].isFavorite,
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveList(prefs, places);

      // Sync favorite toggle to backend
      try {
        await _apiService.toggleFavorite(id);
      } catch (e) {
        if (kDebugMode) {
          print('Error syncing favorite status to backend database: $e');
        }
      }
    }
    return places;
  }

  /// Helper to save list as JSON string
  Future<void> _saveList(SharedPreferences prefs, List<SavedPlace> places) async {
    final jsonList = places.map((p) => p.toJson()).toList();
    await prefs.setString(_placesKey, jsonEncode(jsonList));
  }
}
