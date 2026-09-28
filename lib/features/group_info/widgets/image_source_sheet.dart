import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_action_sheet_item.dart';
import '../../../core/widgets/app_surface.dart';

class ImageSourceSheet extends StatelessWidget {
  const ImageSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.isDark ? AppColors.accent : AppColors.primary;

    return SafeArea(
      child: AppSurface.card(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(AppSpacing.sm),
        color: context.appCardColorStrong,
        borderColor: context.appBorder,
        borderRadius: AppDecorations.radius(AppRadii.xl),
        boxShadow: context.isDark ? const [] : AppShadows.floating,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppActionSheetItem.tile(
              icon: Icons.photo_camera_rounded,
              title: 'image_source.camera'.tr(),
              color: color,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppActionSheetItem.tile(
              icon: Icons.photo_library_rounded,
              title: 'image_source.gallery'.tr(),
              color: color,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}
