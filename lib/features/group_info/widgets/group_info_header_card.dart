import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/safe_network_image.dart';

class GroupInfoHeaderCard extends StatelessWidget {
  final String groupName;
  final String adminName;
  final String groupIconBase64;
  final bool canEditIcon;
  final VoidCallback? onTapIcon;
  final int createdAt;

  const GroupInfoHeaderCard({
    super.key,
    required this.groupName,
    required this.adminName,
    required this.groupIconBase64,
    required this.canEditIcon,
    this.onTapIcon,
    required this.createdAt,
  });

  bool _isNetworkValue(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  String _formatCreatedAt(BuildContext context) {
    if (createdAt <= 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(
      createdAt,
      isUtc: true,
    ).toLocal();

    final currentYear = DateTime.now().year;
    final localizations = MaterialLocalizations.of(context);

    final dayAndMonth = localizations.formatShortMonthDay(date);

    // نعرض السنة فقط إذا لم تكن السنة الحالية.
    if (date.year != currentYear) {
      return '$dayAndMonth ${date.year}';
    }

    return dayAndMonth;
  }

  MemoryImage? _memoryImage(String value) {
    if (value.isEmpty || _isNetworkValue(value)) return null;

    try {
      return MemoryImage(base64Decode(value));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback(BuildContext context, Color avatarTextColor) {
    return Text(
      groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
      style: context.textTheme.headlineSmall?.copyWith(
        color: avatarTextColor,
        fontSize: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = groupIconBase64.trim();
    final memoryImage = _memoryImage(value);
    final isNetwork = _isNetworkValue(value);
    final avatarBackground =
        context.isDark ? context.appSurfaceSoft : AppColors.primarySoft;
    final avatarTextColor =
        context.isDark ? AppColors.accent : AppColors.primaryDark;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: context.appBorder),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: canEditIcon ? onTapIcon : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 37,
                  backgroundColor: avatarBackground,
                  backgroundImage: memoryImage,
                  child:
                      memoryImage == null
                          ? isNetwork
                              ? ClipOval(
                                child: SizedBox(
                                  width: 74,
                                  height: 74,
                                  child: SafeNetworkImage(
                                    url: value,
                                    fit: BoxFit.cover,
                                    placeholderBuilder:
                                        (context) => Center(
                                          child: _fallback(
                                            context,
                                            avatarTextColor,
                                          ),
                                        ),
                                    errorBuilder:
                                        (context) => Center(
                                          child: _fallback(
                                            context,
                                            avatarTextColor,
                                          ),
                                        ),
                                  ),
                                ),
                              )
                              : _fallback(context, avatarTextColor)
                          : null,
                ),
                if (canEditIcon)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('group_info.admin_format', args: [adminName]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                Text(
                  '${tr('group_info.created_at')}: ${_formatCreatedAt(context)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.appTextSecondary,
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
