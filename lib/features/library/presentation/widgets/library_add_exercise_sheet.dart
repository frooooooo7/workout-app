import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/exercise_search.dart';
import '../../domain/models/exercise.dart';
import 'exercise_tracking_picker.dart';

typedef LibraryAddExerciseSubmit = Future<Exercise> Function({
  required String name,
  required List<MuscleGroup> muscles,
  required ExerciseCategory category,
  required String description,
  required ExerciseTracking tracking,
  required DistanceUnit distanceUnit,
  required ExerciseExtras extras,
  Uint8List? imageBytes,
  String? imageFilename,
});

typedef LibraryEditExerciseSubmit = Future<Exercise> Function({
  required String name,
  required List<MuscleGroup> muscles,
  required ExerciseCategory category,
  required String description,
  required ExerciseTracking tracking,
  required DistanceUnit distanceUnit,
  required ExerciseExtras extras,
});

/// Opens a modal bottom sheet to create a user-owned exercise.
/// Returns the created [Exercise] or `null` if cancelled.
Future<Exercise?> showLibraryAddExerciseSheet(
  BuildContext context, {
  required LibraryAddExerciseSubmit onSubmit,
  List<Exercise> existing = const [],
  ValueChanged<Exercise>? onUseSimilar,
}) async {
  final result = await showModalBottomSheet<Exercise?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => _LibraryAddExerciseSheet(
      onSubmit: onSubmit,
      existing: existing,
      onUseSimilar: onUseSimilar,
    ),
  );
  return result;
}

/// Ten sam formularz w trybie edycji własnego ćwiczenia. Zdjęcia nie da się
/// tu zmienić — API aktualizacji go nie przyjmuje.
/// Returns the updated [Exercise] or `null` if cancelled.
Future<Exercise?> showLibraryEditExerciseSheet(
  BuildContext context, {
  required Exercise exercise,
  required LibraryEditExerciseSubmit onSubmit,
  List<Exercise> existing = const [],
}) {
  return showModalBottomSheet<Exercise?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => _LibraryAddExerciseSheet(
      initial: exercise,
      existing: existing,
      onSubmit: ({
        required String name,
        required List<MuscleGroup> muscles,
        required ExerciseCategory category,
        required String description,
        required ExerciseTracking tracking,
        required DistanceUnit distanceUnit,
        required ExerciseExtras extras,
        Uint8List? imageBytes,
        String? imageFilename,
      }) =>
          onSubmit(
        name: name,
        muscles: muscles,
        category: category,
        description: description,
        tracking: tracking,
        distanceUnit: distanceUnit,
        extras: extras,
      ),
    ),
  );
}

class _LibraryAddExerciseSheet extends StatefulWidget {
  const _LibraryAddExerciseSheet({
    required this.onSubmit,
    this.initial,
    this.existing = const [],
    this.onUseSimilar,
  });

  final LibraryAddExerciseSubmit onSubmit;

  /// „Użyj tego” w ostrzeżeniu o duplikacie; `null` — bez przycisku.
  final ValueChanged<Exercise>? onUseSimilar;

  /// Cała baza — do ostrzeżenia o podobnym ćwiczeniu.
  final List<Exercise> existing;

  /// Edytowane ćwiczenie; `null` — tworzymy nowe.
  final Exercise? initial;

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
  final _aliasesController = TextEditingController();
  final _stepsController = TextEditingController();
  final _mistakesController = TextEditingController();

  ExerciseEquipment? _equipment;

  /// Sekcja „Więcej” (inne nazwy, jak wykonać) rozwinięta.
  bool _moreOpen = false;

  /// Podobne ćwiczenie, które już jest w bazie (ostrzeżenie pod nazwą).
  Exercise? _similar;

  Set<MuscleGroup> _selectedMuscles = {};

  /// Grupy zbiorcze, które ćwiczenie miało przed edycją.
  Set<MuscleGroup> _legacyMuscles = {};
  ExerciseCategory _category = ExerciseCategory.compound;
  ExerciseTracking _tracking = ExerciseTracking.weightReps;
  DistanceUnit _distanceUnit = DistanceUnit.km;

  /// Użytkownik sam wybrał tryb — zmiana kategorii już go nie podmienia.
  bool _trackingChosen = false;
  bool _submitting = false;
  String? _errorText;

  XFile? _pickedImage;
  Uint8List? _previewBytes;

  /// Wybieralne mięśnie pogrupowane w partie ciała. Konkretne mięśnie i grupy
  /// jednomięśniowe (klatka, biceps…); grupy zbiorcze (plecy, nogi, barki)
  /// nie niosą informacji, który mięsień pracuje, więc nowego ćwiczenia nimi
  /// nie tagujemy. Starsze ćwiczenie, które już je ma, nadal je pokazuje
  /// ([keep]).
  static Map<MuscleRegion, List<MuscleGroup>> _selectableMuscles(
    Set<MuscleGroup> keep,
  ) => {
    for (final region in MuscleRegion.values)
      region: MuscleGroup.values
          .where((m) => m.region == region && (!m.isCoarse || keep.contains(m)))
          .toList(growable: false),
  };

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameController.text = initial.name;
      _descriptionController.text = initial.description;
      _category = initial.category;
      _tracking = initial.tracking;
      _distanceUnit = initial.distanceUnit;
      _trackingChosen = true;
      _selectedMuscles = initial.workingMuscles.toSet();
      _legacyMuscles = _selectedMuscles.where((m) => m.isCoarse).toSet();
      _equipment = initial.equipment;
      _aliasesController.text = initial.aliases.join(', ');
      _stepsController.text = initial.instructions?.steps.join('\n') ?? '';
      _mistakesController.text =
          initial.instructions?.mistakes.join('\n') ?? '';
      _moreOpen = initial.aliases.isNotEmpty || initial.instructions != null;
    }
  }

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
    _aliasesController.dispose();
    _stepsController.dispose();
    _mistakesController.dispose();
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

  static List<String> _lines(String raw) => [
    for (final line in raw.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  static List<String> _aliasList(String raw) => [
    for (final part in raw.split(RegExp(r'[,\n]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  String? _validateExtras() {
    final aliases = _aliasList(_aliasesController.text);
    if (aliases.length > 10) return 'Inne nazwy: najwyżej 10.';
    if (aliases.any((a) => a.length > 60)) {
      return 'Inna nazwa może mieć co najwyżej 60 znaków.';
    }
    final steps = _lines(_stepsController.text);
    if (steps.length > 10) return 'Kroki: najwyżej 10.';
    if (steps.any((s) => s.length > 300)) {
      return 'Krok może mieć co najwyżej 300 znaków.';
    }
    final mistakes = _lines(_mistakesController.text);
    if (mistakes.length > 6) return 'Częste błędy: najwyżej 6.';
    if (mistakes.any((m) => m.length > 200)) {
      return 'Błąd może mieć co najwyżej 200 znaków.';
    }
    return null;
  }

  ExerciseExtras _buildExtras() {
    final steps = _lines(_stepsController.text);
    final mistakes = _lines(_mistakesController.text);
    return ExerciseExtras(
      equipment: _equipment,
      aliases: _aliasList(_aliasesController.text),
      instructions: steps.isEmpty && mistakes.isEmpty
          ? null
          : ExerciseInstructions(steps: steps, mistakes: mistakes),
    );
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
    final extrasErr = _validateExtras();
    if (extrasErr != null && !_moreOpen) _moreOpen = true;
    final combined = nameErr ?? descErr ?? musclesErr ?? extrasErr;
    setState(() => _errorText = combined);
    if (combined != null) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    // Kolejność wyboru zostaje: pierwszy tag jest celem ćwiczenia.
    final musclesList = _selectedMuscles.toList();

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
        tracking: _tracking,
        distanceUnit: _distanceUnit,
        extras: _buildExtras(),
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

  /// Kardio podpowiada czas + dystans, inne kategorie ciężar × powt. —
  /// dopóki użytkownik sam nie wybrał trybu.
  void _selectCategory(ExerciseCategory category) {
    setState(() {
      _category = category;
      if (!_trackingChosen) {
        _tracking = category == ExerciseCategory.cardio
            ? ExerciseTracking.durationDistance
            : ExerciseTracking.weightReps;
      }
    });
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
                Text(
                  _isEditing ? 'Edytuj ćwiczenie' : 'Nowe ćwiczenie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isEditing
                      ? 'Zapisane treningi zachowają dotychczasową nazwę i partie.'
                      : 'To ćwiczenie będzie widoczne tylko na Twoim koncie.',
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
                  onChanged: (value) {
                    final similar = ExerciseSearch.findSimilar(
                      widget.existing,
                      value,
                      excludeId: widget.initial?.id,
                    );
                    setState(() {
                      _similar = similar;
                      if (_errorText != null) _errorText = null;
                    });
                  },
                ),
                if (_similar != null)
                  _SimilarWarning(
                    exercise: _similar!,
                    onUse: widget.onUseSimilar == null
                        ? null
                        : () {
                            final similar = _similar!;
                            Navigator.of(context).pop(null);
                            widget.onUseSimilar!(similar);
                          },
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
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
                if (!_isEditing) ...[
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
                              cacheWidth: 144,
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
                ],
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
                for (final entry in _selectableMuscles(_legacyMuscles).entries) ...[
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
                const SizedBox(height: 6),
                const Text(
                  'Sprzęt',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final equipment in ExerciseEquipment.values)
                      ChoiceChip(
                        label: Text(equipment.label),
                        selected: _equipment == equipment,
                        showCheckmark: false,
                        onSelected: _submitting
                            ? null
                            : (selected) => setState(
                                () => _equipment = selected ? equipment : null,
                              ),
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.22,
                        ),
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          color: _equipment == equipment
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _equipment == equipment
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: _equipment == equipment
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                  ],
                ),
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
                                  if (v) _selectCategory(c);
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
                const SizedBox(height: 18),
                const Text(
                  'Co zapisujesz',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ExerciseTrackingPicker(
                  tracking: _tracking,
                  distanceUnit: _distanceUnit,
                  enabled: !_submitting,
                  onTrackingChanged: (tracking) => setState(() {
                    _tracking = tracking;
                    _trackingChosen = true;
                  }),
                  onDistanceUnitChanged: (unit) =>
                      setState(() => _distanceUnit = unit),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _moreOpen = !_moreOpen),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Więcej: inne nazwy, jak wykonać',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _moreOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_moreOpen) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _aliasesController,
                    enabled: !_submitting,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: AppColors.primary,
                    decoration: _fieldDecoration(
                      hintText: 'Inne nazwy po przecinku, np. DB bench',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stepsController,
                    enabled: !_submitting,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: AppColors.primary,
                    decoration: _fieldDecoration(
                      hintText: 'Jak wykonać: jeden krok w linii (do 10)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mistakesController,
                    enabled: !_submitting,
                    minLines: 2,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: AppColors.primary,
                    decoration: _fieldDecoration(
                      hintText: 'Częste błędy: jeden w linii (do 6)',
                    ),
                  ),
                ],
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

/// Żółta karta pod nazwą: takie ćwiczenie już jest w bibliotece.
class _SimilarWarning extends StatelessWidget {
  const _SimilarWarning({required this.exercise, this.onUse});

  final Exercise exercise;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFFFB74D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Masz już podobne ćwiczenie: ${exercise.name}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          if (onUse != null)
            TextButton(onPressed: onUse, child: const Text('Użyj tego')),
        ],
      ),
    );
  }
}
