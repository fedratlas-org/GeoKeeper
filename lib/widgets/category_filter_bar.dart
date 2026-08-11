import 'package:flutter/material.dart';
import '../models/saved_place.dart';

class CategoryFilterBar extends StatelessWidget {
  final PlaceCategory? selectedCategory;
  final bool showOnlyFavorites;
  final ValueChanged<PlaceCategory?> onCategorySelected;
  final ValueChanged<bool> onToggleFavorites;

  const CategoryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.showOnlyFavorites,
    required this.onCategorySelected,
    required this.onToggleFavorites,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All Chip
          FilterChip(
            selected: selectedCategory == null && !showOnlyFavorites,
            label: const Text('All Places'),
            avatar: const Icon(Icons.map, size: 18),
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: (selectedCategory == null && !showOnlyFavorites)
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) {
              onCategorySelected(null);
              if (showOnlyFavorites) onToggleFavorites(false);
            },
          ),
          const SizedBox(width: 8),

          // Favorites Chip
          FilterChip(
            selected: showOnlyFavorites,
            label: const Text('Favorites'),
            avatar: Icon(
              showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: Colors.redAccent,
            ),
            selectedColor: Colors.redAccent.withAlpha(50),
            labelStyle: TextStyle(
              color: showOnlyFavorites ? Colors.redAccent : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (val) {
              onToggleFavorites(val);
            },
          ),
          const SizedBox(width: 8),

          // Category Chips
          ...PlaceCategory.values.map((cat) {
            final isSelected = selectedCategory == cat && !showOnlyFavorites;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                avatar: Icon(cat.icon, size: 18, color: cat.color),
                label: Text(cat.displayName),
                selectedColor: cat.color.withAlpha(50),
                labelStyle: TextStyle(
                  color: isSelected ? cat.color : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  onCategorySelected(isSelected ? null : cat);
                  if (showOnlyFavorites) onToggleFavorites(false);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
