import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/saved_place.dart';

class ApiService {
  // ============================================================
  // LIVE VERCEL BACKEND
  // ============================================================

  static const String baseUrl =
      'https://geo-keeper-theta.vercel.app/api';

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('========================================');
        print('BACKEND HEALTH CHECK');
        print('URL: $url');
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('========================================');
        print('❌ BACKEND HEALTH CHECK FAILED');
        print('Error: $e');
        print(stackTrace);
        print('========================================');
      }

      return false;
    }
  }

  // ============================================================
  // GET ALL PLACES
  // ============================================================

  Future<List<SavedPlace>> fetchPlaces() async {
    try {
      final url = Uri.parse('$baseUrl/places');

      if (kDebugMode) {
        print('========================================');
        print('📥 FETCHING PLACES');
        print('GET: $url');
      }

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Failed to fetch places');
        }

        return [];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        if (kDebugMode) {
          print('❌ API did not return a list');
        }

        return [];
      }

      return decoded
          .map(
            (json) => SavedPlace.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('========================================');
        print('❌ FETCH PLACES ERROR');
        print('Error: $e');
        print(stackTrace);
        print('========================================');
      }

      return [];
    }
  }

  // ============================================================
  // SAVE NEW PLACE
  // ============================================================

  Future<SavedPlace?> savePlace(SavedPlace place) async {
    try {
      final url = Uri.parse('$baseUrl/places');

      final requestBody = jsonEncode(place.toJson());

      if (kDebugMode) {
        print('');
        print('========================================');
        print('📤 SAVING PLACE TO CLOUD');
        print('POST: $url');
        print('Request body:');
        print(requestBody);
        print('========================================');
      }

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('');
        print('========================================');
        print('📥 CLOUD SAVE RESPONSE');
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      // Backend returns 201 when a place is successfully created.
      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final savedPlace = SavedPlace.fromJson(
          Map<String, dynamic>.from(decoded),
        );

        if (kDebugMode) {
          print('✅ PLACE SUCCESSFULLY SAVED TO CLOUD');
          print('Cloud ID: ${savedPlace.id}');
        }

        return savedPlace;
      }

      // Print the actual server error.
      if (kDebugMode) {
        print('');
        print('❌ CLOUD SAVE FAILED');
        print('HTTP Status: ${response.statusCode}');
        print('Server response: ${response.body}');
        print('');
      }

      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('');
        print('========================================');
        print('❌ EXCEPTION WHILE SAVING PLACE');
        print('Error: $e');
        print(stackTrace);
        print('========================================');
      }

      return null;
    }
  }

  // ============================================================
  // UPDATE PLACE
  // ============================================================

  Future<SavedPlace?> updatePlace(SavedPlace place) async {
    try {
      final url = Uri.parse('$baseUrl/places/${place.id}');

      final requestBody = jsonEncode(place.toJson());

      if (kDebugMode) {
        print('========================================');
        print('✏️ UPDATING PLACE');
        print('PUT: $url');
        print('Request body: $requestBody');
      }

      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      if (response.statusCode == 200) {
        return SavedPlace.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(response.body),
          ),
        );
      }

      if (kDebugMode) {
        print('❌ UPDATE FAILED');
      }

      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Update error: $e');
        print(stackTrace);
      }

      return null;
    }
  }

  // ============================================================
  // TOGGLE FAVORITE
  // ============================================================

  Future<bool> toggleFavorite(String id) async {
    try {
      final url = Uri.parse('$baseUrl/places/$id/favorite');

      if (kDebugMode) {
        print('========================================');
        print('❤️ TOGGLING FAVORITE');
        print('PATCH: $url');
      }

      final response = await http
          .patch(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Favorite error: $e');
        print(stackTrace);
      }

      return false;
    }
  }

  // ============================================================
  // DELETE PLACE
  // ============================================================

  Future<bool> deletePlace(String id) async {
    try {
      final url = Uri.parse('$baseUrl/places/$id');

      if (kDebugMode) {
        print('========================================');
        print('🗑️ DELETING PLACE');
        print('DELETE: $url');
      }

      final response = await http
          .delete(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Status: ${response.statusCode}');
        print('Response: ${response.body}');
        print('========================================');
      }

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Delete error: $e');
        print(stackTrace);
      }

      return false;
    }
  }
}