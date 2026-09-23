import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/user_avatar.dart';

typedef PickedAvatar = ({Uint8List bytes, String filename});

/// Wybór zdjęcia profilowego: arkusz „Zrób zdjęcie / Wybierz z galerii”
/// (aparat tylko tam, gdzie platforma go obsługuje), inaczej od razu
/// galeria. `null`, gdy użytkownik zrezygnował albo wybór się nie udał.
Future<PickedAvatar?> pickAvatarImage(BuildContext context) async {
  final picker = ImagePicker();
  var source = ImageSource.gallery;
  if (picker.supportsImageSource(ImageSource.camera)) {
    final chosen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => const _AvatarSourceSheet(),
    );
    if (chosen == null) return null;
    source = chosen;
  }

  try {
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (
      bytes: bytes,
      filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
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

/// Duży awatar z plakietką aparatu i przyciskami „Dodaj/Zmień zdjęcie”
/// oraz (gdy podano [onRemove]) „Usuń zdjęcie”. [imageBytes] — świeżo
/// wybrane zdjęcie — ma pierwszeństwo przed [imageUrl].
class AvatarPickerField extends StatelessWidget {
  const AvatarPickerField({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.onPick,
    this.imageUrl,
    this.imageBytes,
    this.onRemove,
    this.enabled = true,
  });

  final String firstName;
  final String lastName;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final bool enabled;

  bool get _hasAvatar => imageBytes != null || imageUrl != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: AppPressable(
            onTap: enabled ? onPick : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar.fromNames(
                  firstName: firstName,
                  lastName: lastName,
                  imageUrl: imageUrl,
                  imageBytes: imageBytes,
                  size: UserAvatarSize.lg,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.onPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed: enabled ? onPick : null,
              child: Text(_hasAvatar ? 'Zmień zdjęcie' : 'Dodaj zdjęcie'),
            ),
            if (_hasAvatar && onRemove != null)
              TextButton(
                onPressed: enabled ? onRemove : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.strengthWeak,
                ),
                child: const Text('Usuń zdjęcie'),
              ),
          ],
        ),
      ],
    );
  }
}

class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text(
                'Zrób zdjęcie',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text(
                'Wybierz z galerii',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}
