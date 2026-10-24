import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/duration_formatter.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../feed/presentation/widgets/post_photo.dart';
import '../../../domain/models/post_draft.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';

/// Linia pod nazwą treningu w arkuszu: „58 min · 4,2 t · 18 serii”.
String postStatsLine(TrainingSessionDetail detail) {
  final sets = detail.completedSetsCount;
  final setsWord = polishPlural(sets, 'seria', 'serie', 'serii');
  final parts = <String>[
    formatDuration(detail.durationSec),
    if (detail.totalVolumeKg > 0) formatVolumeKg(detail.totalVolumeKg),
    '$sets $setsWord',
  ];
  return parts.join(' · ');
}

/// Wynik arkusza „Udostępnij trening”.
sealed class ShareSheetResult {
  const ShareSheetResult();
}

/// Opublikuj (albo zapisz zmiany w) post.
class PublishPost extends ShareSheetResult {
  const PublishPost(this.draft);

  final PostDraft draft;
}

/// Cofnij udostępnienie (tylko przy edycji).
class UnsharePost extends ShareSheetResult {
  const UnsharePost();
}

/// Wybiera zdjęcie z [source]; `null`, gdy użytkownik zrezygnował.
typedef PostPhotoPicker =
    Future<PickedPostPhoto?> Function(BuildContext context, ImageSource source);

/// Otwiera arkusz: zdjęcie (aparat / galeria), tytuł i opis posta. Wszystko
/// opcjonalne — „Opublikuj” działa też z pustymi polami. [editing] zmienia
/// przycisk na „Zapisz” i dodaje „Cofnij udostępnienie”.
Future<ShareSheetResult?> showShareWorkoutSheet(
  BuildContext context, {
  required String planName,
  required String statsLine,
  String? initialTitle,
  String? initialBody,
  String? initialPhotoUrl,
  Uint8List? initialPhotoBytes,
  bool editing = false,
  PostPhotoPicker? pickPhoto,
}) {
  return showModalBottomSheet<ShareSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF111620),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => ShareWorkoutSheet(
      planName: planName,
      statsLine: statsLine,
      initialTitle: initialTitle,
      initialBody: initialBody,
      initialPhotoUrl: initialPhotoUrl,
      initialPhotoBytes: initialPhotoBytes,
      editing: editing,
      pickPhoto: pickPhoto ?? pickPostPhoto,
    ),
  );
}

/// Domyślny wybór zdjęcia: zmniejszone na telefonie (≤ 1600 px, JPEG 85),
/// żeby wysyłka offline-first nie trzymała w kolejce wielu megabajtów.
Future<PickedPostPhoto?> pickPostPhoto(
  BuildContext context,
  ImageSource source,
) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedPostPhoto(
      bytes: bytes,
      filename: file.name.isNotEmpty ? file.name : 'post.jpg',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Nie udało się otworzyć aparatu.'
                : 'Nie udało się otworzyć galerii.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
}

class ShareWorkoutSheet extends StatefulWidget {
  const ShareWorkoutSheet({
    super.key,
    required this.planName,
    required this.statsLine,
    required this.pickPhoto,
    this.initialTitle,
    this.initialBody,
    this.initialPhotoUrl,
    this.initialPhotoBytes,
    this.editing = false,
  });

  final String planName;
  final String statsLine;
  final String? initialTitle;
  final String? initialBody;
  final String? initialPhotoUrl;
  final Uint8List? initialPhotoBytes;
  final bool editing;
  final PostPhotoPicker pickPhoto;

  @override
  State<ShareWorkoutSheet> createState() => _ShareWorkoutSheetState();
}

class _ShareWorkoutSheetState extends State<ShareWorkoutSheet> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.initialBody ?? '',
  );

  /// Nowo wybrane zdjęcie (ma pierwszeństwo przed obecnym).
  PickedPostPhoto? _picked;

  /// Użytkownik usunął obecne zdjęcie.
  bool _removed = false;

  bool get _hasInitialPhoto =>
      widget.initialPhotoBytes != null || widget.initialPhotoUrl != null;

  bool get _showsPhoto => _picked != null || (_hasInitialPhoto && !_removed);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refresh);
    _bodyController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final photo = await widget.pickPhoto(context, source);
    if (!mounted || photo == null) return;
    setState(() {
      _picked = photo;
      _removed = false;
    });
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    if (!picker.supportsImageSource(ImageSource.camera)) {
      return _pick(ImageSource.gallery);
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Zrób zdjęcie'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Wybierz z galerii'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  void _removePhoto() {
    setState(() {
      _picked = null;
      _removed = true;
    });
  }

  PostPhotoChange get _photoChange {
    final picked = _picked;
    if (picked != null) return SetPostPhoto(picked);
    if (_removed && _hasInitialPhoto) return const RemovePostPhoto();
    return const KeepPostPhoto();
  }

  void _publish() {
    Navigator.of(context).pop(
      PublishPost(
        PostDraft(
          title: _titleController.text,
          body: _bodyController.text,
          photo: _photoChange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canUseCamera = ImagePicker().supportsImageSource(ImageSource.camera);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3344),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.editing ? 'Edytuj post' : 'Udostępnij trening',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _SquareIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Zamknij',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showsPhoto
                  ? _PhotoPreview(
                      key: const ValueKey('share-sheet-photo'),
                      bytes: _picked?.bytes ?? widget.initialPhotoBytes,
                      url: _picked == null ? widget.initialPhotoUrl : null,
                      onChange: _changePhoto,
                      onRemove: _removePhoto,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkoutMini(
                          planName: widget.planName,
                          statsLine: widget.statsLine,
                        ),
                        const SizedBox(height: 14),
                        _PhotoSlot(
                          canUseCamera: canUseCamera,
                          onCamera: () => _pick(ImageSource.camera),
                          onGallery: () => _pick(ImageSource.gallery),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _FieldLabel(
              label: 'Tytuł',
              trailing: _titleController.text.isEmpty
                  ? 'opcjonalnie'
                  : '${postTitleLength(_titleController.text)}/$postTitleMaxLength',
            ),
            _PostField(
              key: const ValueKey('share-sheet-title'),
              controller: _titleController,
              hint: widget.planName,
              maxLength: postTitleMaxLength,
              measure: postTitleLength,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _FieldLabel(
              label: 'Opis',
              trailing: _bodyController.text.isEmpty
                  ? 'opcjonalnie'
                  : '${postBodyLength(_bodyController.text)}/$postBodyMaxLength',
            ),
            _PostField(
              key: const ValueKey('share-sheet-body'),
              controller: _bodyController,
              hint: 'Jak poszło? Napisz coś obserwującym…',
              maxLength: postBodyMaxLength,
              measure: postBodyLength,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('share-sheet-publish'),
                onPressed: _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  widget.editing
                      ? Icons.check_rounded
                      : Icons.arrow_upward_rounded,
                  size: 20,
                ),
                label: Text(
                  widget.editing ? 'Zapisz' : 'Opublikuj',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.editing)
              TextButton(
                key: const ValueKey('share-sheet-unshare'),
                onPressed: () => Navigator.of(context).pop(const UnsharePost()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text(
                  'Cofnij udostępnienie',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Możesz to później zmienić w szczegółach treningu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutMini extends StatelessWidget {
  const _WorkoutMini({required this.planName, required this.statsLine});

  final String planName;
  final String statsLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryVariant,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statsLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.canUseCamera,
    required this.onCamera,
    required this.onGallery,
  });

  final bool canUseCamera;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: const Color(0xFF2E3A52), radius: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.surface.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryVariant.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.primaryVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Dodaj zdjęcie',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'opcjonalnie · jedno zdjęcie',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (canUseCamera) ...[
                  _PillButton(
                    key: const ValueKey('share-sheet-camera'),
                    icon: Icons.photo_camera_outlined,
                    label: 'Aparat',
                    onTap: onCamera,
                  ),
                  const SizedBox(width: 8),
                ],
                _PillButton(
                  key: const ValueKey('share-sheet-gallery'),
                  icon: Icons.photo_library_outlined,
                  label: 'Galeria',
                  onTap: onGallery,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    super.key,
    required this.bytes,
    required this.url,
    required this.onChange,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? url;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PostPhoto(
          bytes: bytes,
          url: url,
          aspectRatio: 5 / 4,
          expandable: false,
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            children: [
              _GlassButton(
                key: const ValueKey('share-sheet-change-photo'),
                icon: Icons.refresh_rounded,
                label: 'Zmień',
                onTap: onChange,
              ),
              const SizedBox(width: 6),
              _GlassButton(
                key: const ValueKey('share-sheet-remove-photo'),
                icon: Icons.close_rounded,
                tooltip: 'Usuń zdjęcie',
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.trailing});

  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostField extends StatelessWidget {
  const _PostField({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.measure,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int Function(String text) measure;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [PostLengthFormatter(maxLength, measure)],
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: AppColors.primaryVariant,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.iconOnTile,
        backgroundColor: AppColors.tile,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = label;
    final button = Material(
      color: AppColors.background.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: text == null ? 8 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                if (text != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.tile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: AppColors.iconOnTile, size: 19),
          ),
        ),
      ),
    );
  }
}

/// Przerywana ramka miejsca na zdjęcie.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Limit długości liczony tak jak na serwerze ([measure]), a nie w
/// grafemach jak [LengthLimitingTextInputFormatter]. Wklejony za długi tekst
/// jest ucinany na granicy grafemu, więc emoji nigdy nie zostaje rozcięte.
/// Tekst już dłuższy od limitu (np. stara notatka) nie jest ucinany —
/// można go tylko skracać.
class PostLengthFormatter extends TextInputFormatter {
  PostLengthFormatter(this.maxLength, this.measure);

  final int maxLength;
  final int Function(String text) measure;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newLength = measure(newValue.text);
    if (newLength <= maxLength) return newValue;
    final oldLength = measure(oldValue.text);
    if (oldLength > maxLength) {
      return newLength <= oldLength ? newValue : oldValue;
    }
    final buffer = StringBuffer();
    for (final char in newValue.text.characters) {
      if (measure('$buffer$char') > maxLength) break;
      buffer.write(char);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
