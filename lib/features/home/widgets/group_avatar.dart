import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/safe_network_image.dart';

class GroupAvatar extends StatelessWidget {
  final String groupName;
  final String groupIcon;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const GroupAvatar({
    super.key,
    required this.groupName,
    required this.groupIcon,
    this.radius = 28,
    this.backgroundColor,
    this.textStyle,
  });

  bool _isNetworkValue(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  MemoryImage? _memoryImage(String value) {
    if (value.isEmpty || _isNetworkValue(value)) return null;

    try {
      return MemoryImage(base64Decode(value));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback(BuildContext context) {
    return Text(
      groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
      style: textStyle ??
          context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.72,
            color: context.appPrimary,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = groupIcon.trim();
    final memoryImage = _memoryImage(value);
    final isNetwork = _isNetworkValue(value);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? (context.isDark ? context.appPrimaryGlow : AppColors.primarySoft),
      backgroundImage: memoryImage,
      child: memoryImage == null
          ? isNetwork
              ? ClipOval(
                  child: SizedBox(
                    width: radius * 2,
                    height: radius * 2,
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
    );
  }
}
