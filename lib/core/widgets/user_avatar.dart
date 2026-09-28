import 'package:flutter/material.dart';

import '../services/storage_download_url_cache.dart';
import '../theme/app_theme.dart';
import 'safe_network_image.dart';

class UserAvatar extends StatefulWidget {
  final String imageValue;
  final String displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData fallbackIcon;
  final double? fallbackIconSize;
  final TextStyle? fallbackTextStyle;
  final Widget? loadingWidget;

  const UserAvatar({
    super.key,
    required this.imageValue,
    required this.displayName,
    this.radius = 22,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackIcon = Icons.account_circle_rounded,
    this.fallbackIconSize,
    this.fallbackTextStyle,
    this.loadingWidget,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<String>? _downloadUrlFuture;
  String _lastStoragePath = '';
  String _resolvedDownloadUrl = '';

  void _syncFuture() {
    final value = widget.imageValue.trim();
    if (value.isEmpty || StorageDownloadUrlCache.isHttpUrl(value)) {
      _downloadUrlFuture = null;
      _lastStoragePath = '';
      _resolvedDownloadUrl = '';
      return;
    }

    final storagePath = StorageDownloadUrlCache.normalizePath(value);
    if (storagePath == _lastStoragePath &&
        (_resolvedDownloadUrl.isNotEmpty || _downloadUrlFuture != null)) {
      return;
    }

    _lastStoragePath = storagePath;

    final cachedUrl = StorageDownloadUrlCache.peek(storagePath);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      _resolvedDownloadUrl = cachedUrl;
      _downloadUrlFuture = null;
      return;
    }

    _resolvedDownloadUrl = '';
    _downloadUrlFuture = StorageDownloadUrlCache.resolve(storagePath);
  }

  @override
  void initState() {
    super.initState();
    _syncFuture();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageValue != widget.imageValue) {
      _syncFuture();
    }
  }

  Widget _fallback(BuildContext context) {
    final name = widget.displayName.trim();
    final foreground =
        widget.foregroundColor ??
        (context.isDark ? AppColors.accent : AppColors.primaryDark);

    if (name.isEmpty) {
      return Icon(
        widget.fallbackIcon,
        size: widget.fallbackIconSize ?? widget.radius * 1.25,
        color: foreground,
      );
    }

    return Center(
      child: Text(
        name.characters.first.toUpperCase(),
        style:
            widget.fallbackTextStyle ??
            context.textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: widget.radius * 0.72,
            ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    if (widget.loadingWidget != null) return widget.loadingWidget!;

    return Center(
      child: SizedBox(
        width: widget.radius * 0.45,
        height: widget.radius * 0.45,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _imageFromUrl(String url) {
    final size = widget.radius * 2;

    return ClipOval(
      child: SafeNetworkImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: _loading,
        errorBuilder: _fallback,
        maxWidthDiskCache: 512,
        maxHeightDiskCache: 512,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.imageValue.trim();
    final background =
        widget.backgroundColor ??
        (context.isDark ? context.appSurfaceSoft : AppColors.primarySoft);

    Widget child;
    if (value.isEmpty) {
      child = _fallback(context);
    } else if (StorageDownloadUrlCache.isHttpUrl(value)) {
      child = _imageFromUrl(value);
    } else if (_resolvedDownloadUrl.isNotEmpty) {
      child = _imageFromUrl(_resolvedDownloadUrl);
    } else {
      child = FutureBuilder<String>(
        future: _downloadUrlFuture,
        builder: (context, snapshot) {
          final url = snapshot.data?.trim() ?? '';
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading(context);
          }
          if (snapshot.hasError || url.isEmpty) {
            return _fallback(context);
          }
          return _imageFromUrl(url);
        },
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: background,
      child: ClipOval(
        child: SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: child,
        ),
      ),
    );
  }
}
