import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/saved_place.dart';

class PlaceDetailModal extends StatelessWidget {
  final SavedPlace place;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback onNavigateTo;

  const PlaceDetailModal({
    super.key,
    required this.place,
    required this.onToggleFavorite,
    this.onEdit,
    required this.onDelete,
    required this.onNavigateTo,
  });

  Widget _buildImageWidget(String path) {
    if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = place.category;
    final hasImage = place.imagePath != null && place.imagePath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Place Image Banner
          if (hasImage) ...[
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildImageWidget(place.imagePath!),
            ),
          ],

          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cat.color.withAlpha(35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(cat.icon, color: cat.color, size: 28),
              ),
              const SizedBox(width: 14),

              // Title & Category Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cat.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.displayName,
                        style: TextStyle(
                          color: cat.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite Heart Button
              IconButton(
                icon: Icon(
                  place.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: place.isFavorite ? Colors.redAccent : theme.colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                onPressed: onToggleFavorite,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Rating Row
          Row(
            children: [
              ...List.generate(5, (index) {
                final starValue = index + 1;
                return Icon(
                  starValue <= place.rating
                      ? Icons.star
                      : (starValue - 0.5 <= place.rating ? Icons.star_half : Icons.star_border),
                  color: Colors.amber,
                  size: 20,
                );
              }),
              const SizedBox(width: 8),
              Text(
                place.rating.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          if (place.description.isNotEmpty) ...[
            Text(
              place.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Coordinates & Address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.address ?? '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons Row
          Row(
            children: [
              // Locate Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onNavigateTo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.center_focus_strong, size: 20),
                  label: const Text('Focus Pin'),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Button
              if (onEdit != null) ...[
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit Place',
                ),
                const SizedBox(width: 8),
              ],

              // Delete Button
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(30),
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Delete Place',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
