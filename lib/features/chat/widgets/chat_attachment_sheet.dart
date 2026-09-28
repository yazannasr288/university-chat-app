import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_action_sheet_item.dart';

class ChatAttachmentSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final VoidCallback onFile;
  final VoidCallback onPoll;

  const ChatAttachmentSheet({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onFile,
    required this.onPoll,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _AttachmentAction(
        icon: Icons.camera_alt_rounded,
        title: 'chat.camera'.tr(),
        subtitle: 'chat.take_photo'.tr(),
        color: context.appPrimary,
        onTap: onCamera,
      ),
      _AttachmentAction(
        icon: Icons.image_rounded,
        title: 'chat.photos'.tr(),
        subtitle: 'chat.gallery'.tr(),
        color: AppColors.supportEmerald,
        onTap: onGallery,
      ),
      _AttachmentAction(
        icon: Icons.video_library_rounded,
        title: 'chat.video'.tr(),
        subtitle: 'chat.up_3_minutes'.tr(),
        color: AppColors.supportCoral,
        onTap: onVideo,
      ),
      _AttachmentAction(
        icon: Icons.insert_drive_file_rounded,
        title: 'chat.attachment.file'.tr(),
        subtitle: 'chat.pdf_office'.tr(),
        color: AppColors.supportPurple,
        onTap: onFile,
      ),
      _AttachmentAction(
        icon: Icons.poll_rounded,
        title: 'chat.poll'.tr(),
        subtitle: 'chat.quick_poll'.tr(),
        color: AppColors.accent,
        onTap: onPoll,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.appCardColorStrong,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.appBorder),
            boxShadow: context.isDark ? const [] : AppShadows.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: context.appBorderStrong,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'chat.send_content'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'chat.choose_attachment_type_chat'.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.appTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                itemCount: actions.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return AppActionSheetItem.card(
                    icon: action.icon,
                    title: action.title,
                    subtitle: action.subtitle,
                    color: action.color,
                    onTap: action.onTap,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
