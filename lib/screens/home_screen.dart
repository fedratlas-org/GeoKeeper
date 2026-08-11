import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/saved_place.dart';
import '../services/storage_service.dart';
import '../widgets/map_view_widget.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/place_detail_modal.dart';
import '../widgets/add_place_dialog.dart';
import '../widgets/saved_places_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final GlobalKey<MapViewWidgetState> _mapViewKey = GlobalKey<MapViewWidgetState>();
  final TextEditingController _searchController = TextEditingController();

  List<SavedPlace> _allPlaces = [];
  SavedPlace? _selectedPlace;
  PlaceCategory? _selectedCategory;
  bool _showOnlyFavorites = false;
  bool _isLoading = true;
  bool _isDoubleClickModeActive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    final places = await _storageService.loadSavedPlaces();
    setState(() {
      _allPlaces = places;
      _isLoading = false;
    });
  }

  List<SavedPlace> get _filteredPlaces {
    return _allPlaces.where((p) {
      if (_showOnlyFavorites && !p.isFavorite) return false;
      if (_selectedCategory != null && p.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesDesc = p.description.toLowerCase().contains(q);
        final matchesCat = p.category.displayName.toLowerCase().contains(q);
        final matchesAddress = p.address != null && p.address!.toLowerCase().contains(q);
        if (!matchesName && !matchesDesc && !matchesCat && !matchesAddress) return false;
      }
      return true;
    }).toList();
  }

  void _onSelectPlace(SavedPlace place) {
    setState(() => _selectedPlace = place);
    _mapViewKey.currentState?.animateToLocation(
      LatLng(place.latitude, place.longitude),
    );

    // Show place details modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlaceDetailModal(
        place: place,
        onToggleFavorite: () => _toggleFavorite(place),
        onDelete: () => _confirmDeletePlace(place),
        onNavigateTo: () {
          _mapViewKey.currentState?.animateToLocation(
            LatLng(place.latitude, place.longitude),
            zoom: 16.0,
          );
        },
      ),
    );
  }

  /// Opens AddPlaceDialog pre-filled with the exact LatLng clicked by the user on the map
  Future<void> _openAddPlaceDialog({required double lat, required double lng}) async {
    final result = await showDialog<SavedPlace>(
      context: context,
      builder: (ctx) => AddPlaceDialog(
        initialLat: lat,
        initialLng: lng,
      ),
    );

    if (result != null) {
      final updatedList = await _storageService.savePlace(result);
      setState(() {
        _allPlaces = updatedList;
        _isDoubleClickModeActive = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${result.name}" successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(SavedPlace place) async {
    final updatedList = await _storageService.toggleFavorite(place.id);
    setState(() {
      _allPlaces = updatedList;
      if (_selectedPlace?.id == place.id) {
        _selectedPlace = _selectedPlace!.copyWith(isFavorite: !_selectedPlace!.isFavorite);
      }
    });
  }

  Future<void> _confirmDeletePlace(SavedPlace place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Place'),
        content: Text('Are you sure you want to delete "${place.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updatedList = await _storageService.deletePlace(place.id);
      setState(() {
        _allPlaces = updatedList;
        if (_selectedPlace?.id == place.id) {
          _selectedPlace = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${place.name}"')),
        );
      }
    }
  }

  void _openSavedPlacesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: SavedPlacesSheet(
          places: _allPlaces,
          onPlaceTap: (place) {
            Navigator.pop(ctx);
            _onSelectPlace(place);
          },
          onToggleFavorite: (place) => _toggleFavorite(place),
          onDeletePlace: (place) => _confirmDeletePlace(place),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main Map View
                MapViewWidget(
                  key: _mapViewKey,
                  places: _filteredPlaces,
                  selectedPlace: _selectedPlace,
                  onSelectPlace: _onSelectPlace,
                  onDoubleTapMap: (latLng) {
                    if (_isDoubleClickModeActive) {
                      _openAddPlaceDialog(lat: latLng.latitude, lng: latLng.longitude);
                      setState(() => _isDoubleClickModeActive = false);
                    }
                  },
                  onTapMap: (latLng) {
                    if (_isDoubleClickModeActive) {
                      _openAddPlaceDialog(lat: latLng.latitude, lng: latLng.longitude);
                      setState(() => _isDoubleClickModeActive = false);
                    }
                  },
                ),

                // Top Search Overlay Bar
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Search Input Field
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withAlpha(245),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                          decoration: InputDecoration(
                            hintText: 'Search saved places, category, address...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchQuery.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.bookmarks_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  tooltip: 'Show Saved Places',
                                  onPressed: _openSavedPlacesSheet,
                                ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),

                      // Category Filter Bar
                      CategoryFilterBar(
                        selectedCategory: _selectedCategory,
                        showOnlyFavorites: _showOnlyFavorites,
                        onCategorySelected: (cat) {
                          setState(() => _selectedCategory = cat);
                        },
                        onToggleFavorites: (fav) {
                          setState(() => _showOnlyFavorites = fav);
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom Controls Row
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Mode Guidance Banner
                      if (_isDoubleClickModeActive)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withAlpha(120),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('📍', style: TextStyle(fontSize: 15)),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Double-click anywhere on the map to save place at that location!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom Pill Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // STEP 1: Bottom Left "📍 Save Place" Button (Toggles Mode & Message ONLY)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isDoubleClickModeActive
                                    ? [const Color(0xFFF97316), const Color(0xFFEA580C)]
                                    : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withAlpha(100), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isDoubleClickModeActive
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFF4F46E5))
                                      .withAlpha(115),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: () {
                                  // Step 1 & 2: Toggle mode and show message. DO NOT OPEN DIALOG HERE!
                                  setState(() {
                                    _isDoubleClickModeActive = !_isDoubleClickModeActive;
                                  });
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  if (_isDoubleClickModeActive) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Text('📍', style: TextStyle(fontSize: 16)),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Double-click anywhere on the map to save place!',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 5),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFFF97316),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_isDoubleClickModeActive ? '⚡' : '📍', style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isDoubleClickModeActive
                                            ? 'Double-Click Map'
                                            : 'Save Place',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Right: "Show Saved Places" FAB
                          FloatingActionButton.extended(
                            heroTag: 'saved_list_fab',
                            onPressed: _openSavedPlacesSheet,
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: theme.colorScheme.primary,
                            icon: const Icon(Icons.bookmark_added_rounded),
                            label: Text('Show Saved Places (${_allPlaces.length})'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}