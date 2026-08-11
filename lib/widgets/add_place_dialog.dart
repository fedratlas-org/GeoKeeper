import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/saved_place.dart';

class AddPlaceDialog extends StatefulWidget {
  final SavedPlace? initialPlace;
  final double? initialLat;
  final double? initialLng;

  const AddPlaceDialog({
    super.key,
    this.initialPlace,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<AddPlaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  late PlaceCategory _selectedCategory;
  late double _rating;
  late bool _isFavorite;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPlace;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _latController = TextEditingController(
      text: (p?.latitude ?? widget.initialLat ?? 7.8731).toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: (p?.longitude ?? widget.initialLng ?? 80.7718).toStringAsFixed(6),
    );

    _selectedCategory = p?.category ?? PlaceCategory.custom;
    _rating = p?.rating ?? 5.0;
    _isFavorite = p?.isFavorite ?? false;
    _imagePath = p?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
      final lng = double.tryParse(_lngController.text.trim()) ?? 0.0;

      final result = SavedPlace(
        id: widget.initialPlace?.id ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        latitude: lat,
        longitude: lng,
        category: _selectedCategory,
        rating: _rating,
        isFavorite: _isFavorite,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        imagePath: _imagePath,
        createdAt: widget.initialPlace?.createdAt,
      );

      Navigator.of(context).pop(result);
    }
  }

  Widget _buildImageWidget(String path) {
    if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialPlace != null;

    return Dialog(
      backgroundColor: const Color(0xFFEFEFF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B6396).withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: Color(0xFF3B6396),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit Saved Place' : 'Save New Place',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Image Picker Section
                const Text(
                  'Place Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                if (_imagePath != null && _imagePath!.isNotEmpty)
                  Stack(
                    children: [
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.grey.shade300,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImageWidget(_imagePath!),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black.withAlpha(160),
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => setState(() => _imagePath = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B6396),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      side: const BorderSide(color: Color(0xFF94A3B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Pick Image from Device', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),

                const SizedBox(height: 14),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Place Name *',
                    prefixIcon: const Icon(Icons.title, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFE2E8F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),

                // Category Selector
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: PlaceCategory.values.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return ChoiceChip(
                      avatar: Icon(cat.icon, size: 16, color: isSel ? Colors.white : cat.color),
                      label: Text(cat.displayName),
                      selected: isSel,
                      selectedColor: cat.color,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSel ? cat.color : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'Add notes about why you saved this place...',
                    prefixIcon: const Icon(Icons.notes, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFE2E8F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Address / Location label
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address or Subtitle',
                    hintText: 'e.g., Galle Face, Colombo',
                    prefixIcon: const Icon(Icons.place, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFE2E8F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Rating Slider
                Row(
                  children: [
                    Text(
                      'Rating: ${_rating.toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        activeColor: const Color(0xFF3B6396),
                        label: _rating.toStringAsFixed(1),
                        onChanged: (val) => setState(() => _rating = val),
                      ),
                    ),
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  ],
                ),
                const SizedBox(height: 14),

                // Coordinates Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          filled: true,
                          fillColor: const Color(0xFFE2E8F0),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        validator: (val) => double.tryParse(val ?? '') == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          filled: true,
                          fillColor: const Color(0xFFE2E8F0),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        validator: (val) => double.tryParse(val ?? '') == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Favorite Checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add to Favorites', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  secondary: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.redAccent : const Color(0xFF64748B),
                  ),
                  value: _isFavorite,
                  onChanged: (val) => setState(() => _isFavorite = val ?? false),
                ),

                const SizedBox(height: 16),

                // Action Buttons (Cancel & Save)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF94A3B8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Color(0xFF475569))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B6396),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Update Place' : 'Save Place',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
