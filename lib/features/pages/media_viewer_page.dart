import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../services/attachment_download_service.dart';
import '../chat/widgets/attachment_save_button.dart';

class FullScreenImagePage extends StatelessWidget {
  final String url;
  final String? localPath;
  final DownloadableAttachment? attachment;

  const FullScreenImagePage({
    super.key,
    required this.url,
    this.localPath,
    this.attachment,
  });

  Widget _imageError(BuildContext context) {
    final textTheme = context.textTheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: AppDecorations.surface(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: AppDecorations.radius(AppRadii.md),
          borderColor: Colors.white.withValues(alpha: 0.14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_rounded,
              color: Colors.white70,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              'common.could_not_load_image'.tr(),
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingImage(BuildContext context) {
    final textTheme = context.textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoader.inline(
            size: 42,
            strokeWidth: 3,
            color: AppColors.accent,
          ),
          const SizedBox(height: 14),
          Text(
            'common.loading_image'.tr(),
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanLocalPath = localPath?.trim() ?? '';
    final localFile = cleanLocalPath.isEmpty ? null : File(cleanLocalPath);
    final hasLocalFile = localFile?.existsSync() == true;

    return AppPageShell(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      useBackground: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.9,
              maxScale: 4.5,
              child: Center(
                child:
                    hasLocalFile
                        ? Image.file(
                          localFile!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => _imageError(context),
                        )
                        : SafeNetworkImage(
                          url: url,
                          fit: BoxFit.contain,
                          placeholderBuilder: (_) => _loadingImage(context),
                          errorBuilder: (_) => _imageError(context),
                        ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            child: SafeArea(
              child: Material(
                color: Colors.black.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'common.close'.tr(),
                ),
              ),
            ),
          ),
          if (attachment != null)
            PositionedDirectional(
              top: 12,
              end: 12,
              child: SafeArea(
                child: AttachmentSaveButton(
                  attachment: attachment!,
                  compact: true,
                  overlayStyle: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String? localPath;

  const VideoPlayerPage({super.key, required this.url, this.localPath});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController controller;
  bool _controllerCreated = false;
  bool _initializeFailed = false;

  @override
  void initState() {
    super.initState();

    final cleanLocalPath = widget.localPath?.trim() ?? '';
    final localFile = cleanLocalPath.isEmpty ? null : File(cleanLocalPath);

    if (localFile != null && localFile.existsSync()) {
      controller = VideoPlayerController.file(localFile);
      _controllerCreated = true;
      _initializeVideo();
      return;
    }

    final uri = Uri.tryParse(widget.url);
    final validUri =
        uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        (uri.isScheme('http') || uri.isScheme('https'));

    if (!validUri) {
      _initializeFailed = true;
      return;
    }

    controller = VideoPlayerController.networkUrl(uri);
    _controllerCreated = true;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {});
      controller.play();
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _initializeFailed = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializeFailed = true);
    }
  }

  @override
  void dispose() {
    if (_controllerCreated) {
      controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_controllerCreated || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return AppPageShell(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      useBackground: false,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.18),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'common.video_preview'.tr(),
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body:
          !_controllerCreated || _initializeFailed || controller.value.hasError
              ? Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: AppDecorations.surface(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppDecorations.radius(AppRadii.md),
                    borderColor: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    'common.could_not_play_video'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              : controller.value.isInitialized
              ? AnimatedBuilder(
                animation: controller,
                builder: (_, _) {
                  final value = controller.value;
                  final position = value.position;
                  final duration = value.duration;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 24,
                        child: SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: AppDecorations.surface(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: AppDecorations.radius(AppRadii.lg),
                              borderColor: Colors.white.withValues(alpha: 0.08),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _togglePlayPause,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Icon(
                                            value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: VideoProgressIndicator(
                                          controller,
                                          allowScrubbing: true,
                                          padding: EdgeInsets.zero,
                                          colors: VideoProgressColors(
                                            playedColor: AppColors.accent,
                                            bufferedColor: Colors.white24,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
              : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoader.inline(
                      size: 42,
                      strokeWidth: 3,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'common.loading_video'.tr(),
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
