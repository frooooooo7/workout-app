import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

typedef LibraryAddExerciseSubmit = Future<Exercise> Function({
  required String name,
  required List<MuscleGroup> muscles,
  required ExerciseCategory category,
  required String description,
  Uint8List? imageBytes,
  String? imageFilename,
});

/// Opens a modal bottom sheet to create a user-owned exercise.
/// Returns the created [Exercise] or `null` if cancelled.
Future<Exercise?> showLibraryAddExerciseSheet(
  BuildContext context, {
  required LibraryAddExerciseSubmit onSubmit,
}) async {
  final result = await showModalBottomSheet<Exercise?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => _LibraryAddExerciseSheet(onSubmit: onSubmit),
  );
  return result;
}

class _LibraryAddExerciseSheet extends StatefulWidget {
  const _LibraryAddExerciseSheet({required this.onSubmit});

  final LibraryAddExerciseSubmit onSubmit;

  @override
  State<_LibraryAddExerciseSheet> createState() =>
      _LibraryAddExerciseSheetState();
}

class _LibraryAddExerciseSheetState extends State<_LibraryAddExerciseSheet> {
  static const int _maxNameLength = 120;
  static const int _maxDescriptionLength = 2000;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameFocus = FocusNode();

  Set<MuscleGroup> _selectedMuscles = {};
  ExerciseCategory _category = ExerciseCategory.compound;
  bool _submitting = false;
  String? _errorText;

  XFile? _pickedImage;
  Uint8List? _previewBytes;

  /// Wybieralne mięśnie pogrupowane w partie ciała — płaska lista wszystkich
  /// grup jest już na tyle długa, że bez nagłówków nie da się jej skanować.
  static final Map<MuscleRegion, List<MuscleGroup>> _selectableMuscles = {
    for (final region in MuscleRegion.values)
      region: MuscleGroup.values
          .where((m) => m.region == region)
          .toList(growable: false),
  };

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      counterStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
      ),
      filled: true,
      fillColor: AppColors.background,
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String? _validateName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Podaj nazwę ćwiczenia.';
    }
    if (trimmed.length > _maxNameLength) {
      return 'Nazwa może mieć co najwyżej $_maxNameLength znaków.';
    }
    return null;
  }

  String? _validateDescription(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length > _maxDescriptionLength) {
      return 'Opis może mieć co najwyżej $_maxDescriptionLength znaków.';
    }
    return null;
  }

  String? _validateMuscles(Set<MuscleGroup> muscles) {
    if (muscles.isEmpty) {
      return 'Wybierz co najmniej jedną partię mięśniową.';
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImage = file;
      _previewBytes = bytes;
      _errorText = null;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
    });
  }

  Future<void> _handleSave() async {
    final nameErr = _validateName(_nameController.text);
    final descErr = _validateDescription(_descriptionController.text);
    final musclesErr = _validateMuscles(_selectedMuscles);
    final combined = nameErr ?? descErr ?? musclesErr;
    setState(() => _errorText = combined);
    if (combined != null) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final musclesList = _selectedMuscles.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    Uint8List? imageBytes;
    String? imageFilename;
    if (_pickedImage != null && _previewBytes != null) {
      imageBytes = _previewBytes;
      imageFilename = _pickedImage!.name.isNotEmpty
          ? _pickedImage!.name
          : 'image.jpg';
    }

    try {
      final exercise = await widget.onSubmit(
        name: _nameController.text.trim(),
        muscles: musclesList,
        category: _category,
        description: _descriptionController.text.trim(),
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );
      if (!mounted) return;
      Navigator.of(context).pop(exercise);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText =
            'Nie udało się zapisać ćwiczenia. Sprawdź połączenie i spróbuj ponownie.';
      });
    }
  }

  void _toggleMuscle(MuscleGroup m) {
    setState(() {
      if (_selectedMuscles.contains(m)) {
        _selectedMuscles = {..._selectedMuscles}..remove(m);
      } else {
        _selectedMuscles = {..._selectedMuscles, m};
      }
      _errorText = null;
    });
  }

  static ButtonStyle _outlineBaseStyle({
    required Color foreground,
    required Color borderColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      side: BorderSide(color: borderColor),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nowe ćwiczenie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'To ćwiczenie będzie widoczne tylko na Twoim koncie.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  enabled: !_submitting,
                  maxLength: _maxNameLength,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: AppColors.primary,
                  decoration: _fieldDecoration(hintText: 'Nazwa ćwiczenia'),
                  onChanged: (_) => setState(() => _errorText = null),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descriptionController,
                  enabled: !_submitting,
                  maxLength: _maxDescriptionLength,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: AppColors.primary,
                  decoration: _fieldDecoration(
                    hintText:
                        'Opis (technika, tempo, uwagi — opcjonalnie)',
                  ),
                  onChanged: (_) => setState(() => _errorText = null),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Zdjęcie',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickImage,
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        label: const Text('Wybierz z galerii'),
                        style: _outlineBaseStyle(
                          foreground: AppColors.textSecondary,
                          borderColor: AppColors.border,
                        ),
                      ),
                    ),
                    if (_previewBytes != null) ...[
                      const SizedBox(width: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _previewBytes!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Material(
                              color: AppColors.surface,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _submitting ? null : _clearImage,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Partie mięśniowe',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in _selectableMuscles.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 2),
                    child: Text(
                      entry.key.label.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((m) {
                      final selected = _selectedMuscles.contains(m);
                      return FilterChip(
                        label: Text(m.shortLabel),
                        selected: selected,
                        onSelected: _submitting ? null : (_) => _toggleMuscle(m),
                        showCheckmark: false,
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.22),
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Kategoria',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ExerciseCategory.values.map((c) {
                      final selected = c == _category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.label),
                          selected: selected,
                          onSelected: _submitting
                              ? null
                              : (v) {
                                  if (v) setState(() => _category = c);
                                },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.22),
                          backgroundColor: AppColors.background,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color:
                                selected ? AppColors.primary : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(null),
                        style: _outlineBaseStyle(
                          foreground: AppColors.textSecondary,
                          borderColor: AppColors.border,
                        ),
                        child: const Text('Anuluj'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _handleSave,
                        style: _outlineBaseStyle(
                          foreground: AppColors.primary,
                          borderColor: AppColors.primary,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text('Zapisz'),
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
