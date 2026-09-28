import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/services/storage_download_url_cache.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_list_tile_card.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../services/attachment_download_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final AttachmentDownloadService _service = AttachmentDownloadService.instance;
  final Set<String> _removingKeys = <String>{};
  late Future<List<SavedAttachmentRecord>> _future =
      _service.savedAttachments();

  void _reload() {
    setState(() {
      _future = _service.savedAttachments();
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.mic_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _fallbackPreview(SavedAttachmentRecord record) {
    return AppIconBadge(icon: _iconFor(record.type), size: 52, iconSize: 24);
  }

  Widget _squarePreview({required Widget child, Widget? overlay}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          fit: StackFit.expand,
          children: [child, if (overlay != null) Center(child: overlay)],
        ),
      ),
    );
  }

  Widget _videoPlayOverlay() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 23),
      ),
    );
  }

  int _previewCacheDimension() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return (52 * pixelRatio).ceil().clamp(64, 512).toInt();
  }

  Widget _networkThumbnail(String url, SavedAttachmentRecord record) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return _fallbackPreview(record);
    final cacheDimension = _previewCacheDimension();

    return _squarePreview(
      overlay: record.type == 'video' ? _videoPlayOverlay() : null,
      child: CachedNetworkImage(
        imageUrl: cleanUrl,
        fit: BoxFit.cover,
        memCacheWidth: cacheDimension,
        memCacheHeight: cacheDimension,
        maxWidthDiskCache: cacheDimension,
        maxHeightDiskCache: cacheDimension,
        fadeInDuration: AppMotion.resolve(context, AppMotion.fast),
        placeholder: (context, url) => _fallbackPreview(record),
        errorWidget: (context, url, error) => _fallbackPreview(record),
      ),
    );
  }

  Widget _videoStorageThumbnail(SavedAttachmentRecord record) {
    final thumbnailStoragePath = record.thumbnailStoragePath.trim();
    if (thumbnailStoragePath.isEmpty) return _videoFallbackPreview(record);

    final cachedUrl = StorageDownloadUrlCache.peek(thumbnailStoragePath);
    if (cachedUrl != null && cachedUrl.trim().isNotEmpty) {
      return _networkThumbnail(cachedUrl, record);
    }

    return FutureBuilder<String>(
      future: StorageDownloadUrlCache.resolve(thumbnailStoragePath),
      builder: (context, snapshot) {
        final url = snapshot.data?.trim() ?? '';
        if (url.isNotEmpty) return _networkThumbnail(url, record);
        return _videoFallbackPreview(record);
      },
    );
  }

  Widget _videoFallbackPreview(SavedAttachmentRecord record) {
    return AppIconBadge(
      icon: Icons.play_circle_fill_rounded,
      size: 52,
      iconSize: 28,
      color: context.appPrimary,
      backgroundColor: context.appPrimary.withValues(alpha: 0.12),
    );
  }

  Widget _previewFor(SavedAttachmentRecord record) {
    final cleanPath = record.path.trim();
    final file = cleanPath.isEmpty ? null : File(cleanPath);
    final cacheDimension = _previewCacheDimension();

    if (record.type == 'image' && file != null && file.existsSync()) {
      return _squarePreview(
        child: Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: cacheDimension,
          cacheHeight: cacheDimension,
          errorBuilder:
              (context, error, stackTrace) => _fallbackPreview(record),
        ),
      );
    }

    if (record.type == 'video') {
      final localThumbnailPath = record.thumbnailPath.trim();
      if (localThumbnailPath.isNotEmpty) {
        final thumbnailFile = File(localThumbnailPath);
        if (thumbnailFile.existsSync()) {
          return _squarePreview(
            overlay: _videoPlayOverlay(),
            child: Image.file(
              thumbnailFile,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: cacheDimension,
              cacheHeight: cacheDimension,
              errorBuilder:
                  (context, error, stackTrace) => _videoFallbackPreview(record),
            ),
          );
        }
      }

      final thumbnailUrl = record.thumbnailUrl.trim();
      if (thumbnailUrl.isNotEmpty) {
        return _networkThumbnail(thumbnailUrl, record);
      }

      return _videoStorageThumbnail(record);
    }

    return _fallbackPreview(record);
  }

  String _dateLabel(int timestamp) {
    if (timestamp <= 0) return '';
    final locale = context.locale.toString();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('d MMM yyyy • HH:mm', locale).format(date);
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  Future<void> _open(SavedAttachmentRecord record) async {
    final file = File(record.path);
    if (!await file.exists()) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'downloads.file_missing'.tr(),
        type: SnackType.error,
      );
      _reload();
      return;
    }

    final result = await OpenFilex.open(record.path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      showAppSnackBar(
        context,
        'chat.could_not_open_saved_file'.tr(),
        type: SnackType.error,
      );
    }
  }

  Future<void> _remove(SavedAttachmentRecord record) async {
    if (_removingKeys.contains(record.key)) return;

    setState(() => _removingKeys.add(record.key));

    try {
      await _service.removeSavedAttachment(record, deleteFile: true);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'downloads.removed'.tr(),
        type: SnackType.success,
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(error), type: SnackType.error);
    } finally {
      if (mounted) {
        setState(() => _removingKeys.remove(record.key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'downloads.title'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'common.retry'.tr(),
          onPressed: _reload,
        ),
      ],
      body: FutureBuilder<List<SavedAttachmentRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records =
              snapshot.data
                  ?.where((record) => !_removingKeys.contains(record.key))
                  .toList(growable: false) ??
              const <SavedAttachmentRecord>[];

          return AppStateView(
            loading: !snapshot.hasData && !snapshot.hasError,
            error: snapshot.hasError ? 'downloads.load_failed'.tr() : null,
            empty: snapshot.hasData && records.isEmpty,
            emptyIcon: Icons.download_done_rounded,
            emptyText: 'downloads.empty'.tr(),
            onRetry: snapshot.hasError ? _reload : null,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final size = _formatSize(record.sizeBytes);
                final date = _dateLabel(record.savedAt);

                return AppListTileCard(
                  leading: _previewFor(record),
                  title: Text(
                    record.fileName.isNotEmpty
                        ? record.fileName
                        : record.path.split(Platform.pathSeparator).last,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (date.isNotEmpty) date,
                      if (size.isNotEmpty) size,
                      record.path,
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(record),
                  trailing: IconButton(
                    icon:
                        _removingKeys.contains(record.key)
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.close_rounded),
                    tooltip: 'downloads.remove'.tr(),
                    onPressed:
                        _removingKeys.contains(record.key)
                            ? null
                            : () => _remove(record),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
