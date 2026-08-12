import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/saved_place.dart';

class ApiService {
  // Live Vercel Cloud Backend API URL
  static const String baseUrl = 'https://geo-keeper-h4td4u1hg-dinal-peraketiyas-projects.vercel.app/api';

  /// Check backend server health status
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 4),
      );
      if (kDebugMode) {
        print('Backend health check status: ${response.statusCode}');
      }
      return response.statusCode == 200 && response.body.contains('status');
    } catch (e) {
      if (kDebugMode) {
        print('Backend server health check failed: $e');
      }
      return false;
    }
  }

  /// Fetch all places from backend API
  Future<List<SavedPlace>> fetchPlaces() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/places')).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => SavedPlace.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching places from API: $e');
      }
    }
    return [];
  }

  /// Save a new place to backend API
  Future<SavedPlace?> savePlace(SavedPlace place) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/places'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(place.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return SavedPlace.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving place to API: $e');
      }
    }
    return null;
  }

  /// Update an existing place in backend API
  Future<SavedPlace?> updatePlace(SavedPlace place) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/places/${place.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(place.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return SavedPlace.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating place in API: $e');
      }
    }
    return null;
  }

  /// Toggle favorite status of a place in backend API
  Future<bool> toggleFavorite(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/places/$id/favorite'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite in API: $e');
      }
      return false;
    }
  }

  /// Delete a place from backend API
  Future<bool> deletePlace(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/places/$id'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting place from API: $e');
      }
      return false;
    }
  }
}
