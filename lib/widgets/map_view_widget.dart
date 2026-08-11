import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/saved_place.dart';
import '../config/api_keys.dart';

class MapViewWidget extends StatefulWidget {
  final List<SavedPlace> places;
  final SavedPlace? selectedPlace;
  final LatLng initialCameraPosition;
  final ValueChanged<SavedPlace> onSelectPlace;
  final ValueChanged<LatLng>? onLongPressMap;
  final ValueChanged<LatLng>? onTapMap;
  final ValueChanged<LatLng>? onDoubleTapMap;
  final bool forceFallback;

  const MapViewWidget({
    super.key,
    required this.places,
    this.selectedPlace,
    this.initialCameraPosition = const LatLng(7.8731, 80.7718), // Sri Lanka center default
    required this.onSelectPlace,
    this.onLongPressMap,
    this.onTapMap,
    this.onDoubleTapMap,
    this.forceFallback = false,
  });

  @override
  State<MapViewWidget> createState() => MapViewWidgetState();
}

class MapViewWidgetState extends State<MapViewWidget> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _forceFallbackMode = false;

  void animateToLocation(LatLng position, {double zoom = 15.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: zoom,
        ),
      ),
    );
  }

  void toggleMapType() {
    setState(() {
      switch (_currentMapType) {
        case MapType.normal:
          _currentMapType = MapType.satellite;
          break;
        case MapType.satellite:
          _currentMapType = MapType.terrain;
          break;
        case MapType.terrain:
          _currentMapType = MapType.hybrid;
          break;
        case MapType.hybrid:
          _currentMapType = MapType.normal;
          break;
        default:
          _currentMapType = MapType.normal;
      }
    });
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    for (final place in widget.places) {
      final isSelected = widget.selectedPlace?.id == place.id;

      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: '${place.category.displayName} • ⭐ ${place.rating.toStringAsFixed(1)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(place.category.markerHue),
          zIndexInt: isSelected ? 10 : 1,
          onTap: () => widget.onSelectPlace(place),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Check if valid API key is set or if fallback mode is forced
    final hasKey = ApiKeys.hasValidKey;

    if (!hasKey || _forceFallbackMode || widget.forceFallback) {
      return Stack(
        children: [
          _buildInteractiveFallbackMap(context),

          // Toggle back button if key is set
          if (hasKey)
            Positioned(
              top: 100,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'mode_toggle_fab',
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                onPressed: () => setState(() => _forceFallbackMode = false),
                tooltip: 'Switch to Live Google Maps',
                child: const Icon(Icons.map),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialCameraPosition,
            zoom: 8.5,
          ),
          mapType: _currentMapType,
          markers: _buildMarkers(),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.selectedPlace != null) {
              animateToLocation(
                LatLng(widget.selectedPlace!.latitude, widget.selectedPlace!.longitude),
              );
            }
          },
          onTap: (position) {
            if (widget.onTapMap != null) {
              widget.onTapMap!(position);
            }
          },
          onLongPress: (position) {
            if (widget.onDoubleTapMap != null) {
              widget.onDoubleTapMap!(position);
            } else if (widget.onLongPressMap != null) {
              widget.onLongPressMap!(position);
            }
          },
        ),

        // Map Type & Mode Toggle Overlay Buttons
        Positioned(
          top: 100,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'map_type_fab',
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: toggleMapType,
                tooltip: 'Change Map Type',
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'recenter_fab',
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: () {
                  if (widget.places.isNotEmpty) {
                    final first = widget.selectedPlace ?? widget.places.first;
                    animateToLocation(LatLng(first.latitude, first.longitude));
                  }
                },
                tooltip: 'Center on Places',
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'fallback_mode_fab',
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: () => setState(() => _forceFallbackMode = true),
                tooltip: 'Switch to Interactive Preview',
                child: const Icon(Icons.grid_view),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Interactive simulated map view if Google API Key is not yet provided
  Widget _buildInteractiveFallbackMap(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: const Color(0xFFE8ECEF),
      child: Stack(
        children: [
          // Grid lines simulation
          CustomPaint(
            size: Size.infinite,
            painter: MapGridPainter(gridColor: Colors.blueGrey.withAlpha(40)),
          ),

          // API Key Banner
          Positioned(
            top: 90,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(240),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Maps Preview Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Add your Google Maps API key in lib/config/api_keys.dart to load live map tiles.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Interactive Markers Simulation
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: GestureDetector(
                  onDoubleTapDown: (details) {
                    final localOffset = details.localPosition;
                    final lng = 80.7718 + ((localOffset.dx - 400) / 3000);
                    final lat = 7.8731 - ((localOffset.dy - 400) / 3000);
                    final pos = LatLng(lat, lng);
                    if (widget.onDoubleTapMap != null) {
                      widget.onDoubleTapMap!(pos);
                    } else if (widget.onLongPressMap != null) {
                      widget.onLongPressMap!(pos);
                    }
                  },
                  onTapUp: (details) {
                    if (widget.onTapMap != null) {
                      final localOffset = details.localPosition;
                      final lng = 80.7718 + ((localOffset.dx - 400) / 3000);
                      final lat = 7.8731 - ((localOffset.dy - 400) / 3000);
                      widget.onTapMap!(LatLng(lat, lng));
                    }
                  },
                  child: Container(
                    width: 800,
                    height: 800,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                      // Render places as interactive pins
                      ...widget.places.map((place) {
                        // Map coordinates offset to simulated pixels
                        final dx = ((place.longitude - 80.7718) * 3000) + 400;
                        final dy = (-(place.latitude - 7.8731) * 3000) + 400;
                        final isSel = widget.selectedPlace?.id == place.id;
                        final cat = place.category;

                        return Positioned(
                          left: dx.clamp(40.0, 740.0),
                          top: dy.clamp(40.0, 740.0),
                          child: GestureDetector(
                            onTap: () => widget.onSelectPlace(place),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? cat.color : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: cat.color, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(40),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat.icon,
                                        size: 16,
                                        color: isSel ? Colors.white : cat.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        place.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isSel ? Colors.white : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: cat.color,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

          // Long press prompt instruction
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '💡 Tap any pin or press "+ Add Place" to manage saved places',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Grid Painter for simulated map background
class MapGridPainter extends CustomPainter {
  final Color gridColor;
  MapGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
