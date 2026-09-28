import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/safe_network_image.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String groupId;
  final String groupName;
  final String groupIconBase64;
  final VoidCallback? onInfoTap;
  final VoidCallback? onSearchTap;
  static const int _maxMemoryImageCacheEntries = 80;
  static final Map<String, MemoryImage?> _memoryImageCache =
      <String, MemoryImage?>{};

  const ChatHeader({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupIconBase64,
    this.onInfoTap,
    this.onSearchTap,
  });

  LinearGradient _headerGradient(BuildContext context) {
    if (context.isDark) {
      return const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFF082D55),
          Color(0xFF075A9E),
          Color(0xFF0C78B7),
          Color(0xFF09283F),
        ],
        stops: [0.0, 0.38, 0.72, 1.0],
      );
    }

    return AppGradients.brand;
  }

  LinearGradient _headerGlowGradient(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: context.isDark ? 0.12 : 0.20),
        Colors.white.withValues(alpha: 0.00),
      ],
    );
  }

  bool _isNetworkValue(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  MemoryImage? _memoryImage(String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty || _isNetworkValue(cleanValue)) return null;

    if (_memoryImageCache.containsKey(cleanValue)) {
      return _memoryImageCache[cleanValue];
    }

    MemoryImage? image;
    try {
      image = MemoryImage(base64Decode(cleanValue));
    } catch (_) {
      image = null;
    }

    if (_memoryImageCache.length >= _maxMemoryImageCacheEntries) {
      _memoryImageCache.remove(_memoryImageCache.keys.first);
    }

    _memoryImageCache[cleanValue] = image;
    return image;
  }

  Widget _fallback(BuildContext context) {
    return Text(
      groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
      style: context.textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = groupIconBase64.trim();
    final memoryImage = _memoryImage(value);
    final isNetwork = _isNetworkValue(value);

    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _headerGradient(context),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(
                alpha: context.isDark ? 0.20 : 0.12,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              top: -54,
              end: -38,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: -70,
              start: 42,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(
                      alpha: context.isDark ? 0.09 : 0.12,
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: _headerGlowGradient(context),
              ),
            ),
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.accent.withValues(alpha: 0.78),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Hero(
            tag: 'group-avatar-$groupId',
            transitionOnUserGestures: true,
            createRectTween: (begin, end) {
              return MaterialRectCenterArcTween(begin: begin, end: end);
            },
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(2.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.gold,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    backgroundImage: memoryImage,
                    child: memoryImage == null
                        ? isNetwork
                            ? ClipOval(
                                child: SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: SafeNetworkImage(
                                    url: value,
                                    fit: BoxFit.cover,
                                    placeholderBuilder: (context) => Center(
                                      child: _fallback(context),
                                    ),
                                    errorBuilder: (context) => Center(
                                      child: _fallback(context),
                                    ),
                                  ),
                                ),
                              )
                            : _fallback(context)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'chat.chat_room'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (onSearchTap != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              onPressed: onSearchTap,
            ),
          ),
        if (onInfoTap != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: onInfoTap,
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
