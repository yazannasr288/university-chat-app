import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/bidi_text.dart';
import '../../../data/models/chat_message.dart';
import '../controllers/chat_controller.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isCancelled;
  final Duration recordingDuration;
  final double recordingLevel;
  final ValueListenable<ChatRecordingUiState> recordingUiState;
  final FocusNode focusNode;
  final bool isSendingText;
  final bool isSendingAttachment;
  final bool isSendingRecording;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordTap;
  final VoidCallback onRecordCancel;
  final VoidCallback onRecordSend;
  final GestureLongPressStartCallback onRecordStart;
  final GestureLongPressMoveUpdateCallback onRecordMove;
  final GestureLongPressEndCallback onRecordEnd;
  final ChatMessage? replyingToMessage;
  final VoidCallback? onCancelReply;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isCancelled,
    required this.recordingDuration,
    required this.recordingLevel,
    required this.recordingUiState,
    required this.focusNode,
    this.isSendingText = false,
    this.isSendingAttachment = false,
    this.isSendingRecording = false,
    required this.onSend,
    required this.onAttach,
    required this.onRecordTap,
    required this.onRecordCancel,
    required this.onRecordSend,
    required this.onRecordStart,
    required this.onRecordMove,
    required this.onRecordEnd,
    this.replyingToMessage,
    this.onCancelReply,
  });

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatRecordingUiState>(
      valueListenable: recordingUiState,
      builder: (context, recordingState, _) {
        final recordingActive = isRecording || recordingState.isRecording;
        final cancelled =
            recordingActive ? recordingState.isCancelled : isCancelled;
        final duration =
            recordingActive ? recordingState.duration : recordingDuration;
        final level = recordingActive ? recordingState.level : recordingLevel;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final inputBusy =
            isSendingText || isSendingAttachment || isSendingRecording;

        return AnimatedBuilder(
          animation: focusNode,
          builder: (context, _) {
            final focused = focusNode.hasFocus && !recordingActive;

            return AnimatedPadding(
              duration: AppMotion.resolve(context, AppMotion.quick),
              curve: AppMotion.standard,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    curve: AppMotion.standard,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.appCardColorStrong,
                      borderRadius: BorderRadius.circular(
                        recordingActive ? 24 : 30,
                      ),
                      border: Border.all(
                        color: cancelled
                            ? AppColors.error.withValues(alpha: 0.76)
                            : focused
                                ? context.appPrimary.withValues(alpha: 0.72)
                                : context.appBorder,
                        width: focused || cancelled ? 1.35 : 1,
                      ),
                      boxShadow: context.isDark
                          ? [
                              if (focused)
                                BoxShadow(
                                  color: context.appPrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                  spreadRadius: -7,
                                ),
                            ]
                          : [
                              ...AppShadows.floating,
                              if (focused) ...AppShadows.brandGlow,
                            ],
                    ),
                    child: Stack(
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.medium,
                          ),
                          reverseDuration: AppMotion.resolve(
                            context,
                            AppMotion.fast,
                          ),
                          switchInCurve: AppMotion.entrance,
                          switchOutCurve: AppMotion.exit,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.985,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: recordingActive
                              ? _RecordingComposer(
                                  key: const ValueKey('recording-composer'),
                                  durationLabel: _formatDuration(duration),
                                  level: level,
                                  isCancelled: cancelled,
                                  isSending: isSendingRecording,
                                  onCancel: isSendingRecording
                                      ? null
                                      : onRecordCancel,
                                  onSend: isSendingRecording
                                      ? null
                                      : onRecordSend,
                                )
                              : Column(
                                  key: const ValueKey('text-composer'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSize(
                                      duration: AppMotion.resolve(
                                        context,
                                        AppMotion.medium,
                                      ),
                                      curve: AppMotion.emphasized,
                                      alignment: Alignment.topCenter,
                                      child: replyingToMessage != null
                                          ? _ReplyPreview(
                                              key: ValueKey<String>(
                                                'reply-${replyingToMessage!.id}',
                                              ),
                                              message: replyingToMessage!,
                                              onCancel: onCancelReply,
                                            )
                                          : const SizedBox.shrink(
                                              key: ValueKey<String>(
                                                'no-reply',
                                              ),
                                            ),
                                    ),
                                    _TextComposer(
                                      controller: controller,
                                      focusNode: focusNode,
                                      isSendingText: isSendingText,
                                      isSendingAttachment:
                                          isSendingAttachment,
                                      inputBusy: inputBusy,
                                      onAttach: inputBusy ? null : onAttach,
                                      onSend: inputBusy ? null : onSend,
                                      onRecordTap:
                                          inputBusy ? null : onRecordTap,
                                      onRecordStart:
                                          inputBusy ? null : onRecordStart,
                                      onRecordMove:
                                          inputBusy ? null : onRecordMove,
                                      onRecordEnd:
                                          inputBusy ? null : onRecordEnd,
                                    ),
                                  ],
                                ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          start: 28,
                          end: 28,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: AppMotion.resolve(
                                context,
                                AppMotion.fast,
                              ),
                              opacity: focused ? 1 : 0,
                              child: Container(
                                height: 2,
                                decoration: const BoxDecoration(
                                  gradient: AppGradients.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TextComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSendingText;
  final bool isSendingAttachment;
  final bool inputBusy;
  final VoidCallback? onAttach;
  final VoidCallback? onSend;
  final VoidCallback? onRecordTap;
  final GestureLongPressStartCallback? onRecordStart;
  final GestureLongPressMoveUpdateCallback? onRecordMove;
  final GestureLongPressEndCallback? onRecordEnd;
  const _TextComposer({
    required this.controller,
    required this.focusNode,
    required this.isSendingText,
    required this.isSendingAttachment,
    required this.inputBusy,
    required this.onAttach,
    required this.onSend,
    required this.onRecordTap,
    required this.onRecordStart,
    required this.onRecordMove,
    required this.onRecordEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          final effectiveTextDirection = chatTextDirectionFor(
            value.text,
            fallback: Directionality.of(context),
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'chat.attach'.tr(),
                backgroundColor: context.appChatInputFill,
                foregroundColor:
                    isSendingAttachment
                        ? context.appTextMuted
                        : context.appPrimary,
                onTap: onAttach,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textDirection: effectiveTextDirection,
                  textAlign: TextAlign.start,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onTapOutside: (_) {},
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'chat.type_message'.tr(),
                    hintStyle: context.textTheme.bodyMedium?.copyWith(
                      color: context.appTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: context.appChatInputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: context.appPrimary.withValues(alpha: 0.65),
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                switchInCurve: AppMotion.entrance,
                switchOutCurve: AppMotion.standard,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child:
                    hasText
                        ? _SendButton(
                          key: const ValueKey('send-button'),
                          onTap: onSend,
                          isBusy: isSendingText,
                        )
                        : GestureDetector(
                          key: const ValueKey('record-button'),
                          onLongPressStart: onRecordStart,
                          onLongPressMoveUpdate: onRecordMove,
                          onLongPressEnd: onRecordEnd,
                          child: _RoundIconButton(
                            icon: Icons.mic_rounded,
                            tooltip: 'chat.voice_recording'.tr(),
                            backgroundColor:
                                inputBusy
                                    ? context.appTextMuted.withValues(
                                      alpha: 0.25,
                                    )
                                    : context.appPrimary,
                            foregroundColor: Colors.white,
                            onTap: onRecordTap,
                          ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordingComposer extends StatelessWidget {
  final String durationLabel;
  final double level;
  final bool isCancelled;
  final bool isSending;
  final VoidCallback? onCancel;
  final VoidCallback? onSend;

  const _RecordingComposer({
    super.key,
    required this.durationLabel,
    required this.level,
    required this.isCancelled,
    this.isSending = false,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final waveColor = isCancelled ? Colors.white : context.appPrimary;
    final textColor = isCancelled ? Colors.white : context.appTextPrimary;
    final metaColor =
        isCancelled
            ? Colors.white.withValues(alpha: 0.78)
            : context.appTextSecondary;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'chat.cancel_recording'.tr(),
            backgroundColor:
                isCancelled
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppColors.error.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
            foregroundColor: isCancelled ? Colors.white : AppColors.error,
            onTap: onCancel,
          ),
          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isCancelled
                            ? 'chat.release_cancel'.tr()
                            : 'chat.recording'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      durationLabel,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: metaColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _RecordingWaveform(
                  level: level,
                  active: !isCancelled,
                  color: waveColor,
                  mutedColor: metaColor.withValues(alpha: 0.28),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          _SendButton(onTap: onSend, isBusy: isSending),
        ],
      ),
    );
  }
}

class _RecordingWaveform extends StatefulWidget {
  final double level;
  final bool active;
  final Color color;
  final Color mutedColor;

  const _RecordingWaveform({
    required this.level,
    required this.active,
    required this.color,
    required this.mutedColor,
  });

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionDisabled = AppMotion.animationsDisabled(context);
    if (widget.active && !_motionDisabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_motionDisabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bars = 18;
    final clampedLevel = widget.level.clamp(0.08, 1.0).toDouble();

    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            children: [
              for (var i = 0; i < bars; i++) ...[
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: AppMotion.resolve(context, AppMotion.fast),
                      curve: AppMotion.standard,
                      height:
                          widget.active
                              ? 6 +
                                  (20 *
                                      clampedLevel *
                                      (0.45 +
                                          0.55 *
                                              math
                                                  .sin(
                                                    (_controller.value *
                                                            math.pi *
                                                            2) +
                                                        i,
                                                  )
                                                  .abs()))
                              : 7 + ((i % 4) * 3),
                      decoration: BoxDecoration(
                        color: widget.active ? widget.color : widget.mutedColor,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ),
                if (i != bars - 1) const SizedBox(width: 3),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isBusy;

  const _SendButton({super.key, required this.onTap, this.isBusy = false});

  @override
  Widget build(BuildContext context) {
    return _ComposerActionButton(
      onTap: isBusy ? null : onTap,
      gradient: AppGradients.primary,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
      child: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.fast),
        switchInCurve: AppMotion.entrance,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: isBusy
            ? const SizedBox(
                key: ValueKey<String>('send-loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.send_rounded,
                key: ValueKey<String>('send-icon'),
                color: Colors.white,
              ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ComposerActionButton(
      tooltip: tooltip,
      onTap: onTap,
      backgroundColor: backgroundColor,
      child: Icon(icon, color: foregroundColor),
    );
  }
}

class _ComposerActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow> boxShadow;

  const _ComposerActionButton({
    required this.child,
    required this.onTap,
    this.tooltip,
    this.backgroundColor,
    this.gradient,
    this.boxShadow = const [],
  });

  @override
  State<_ComposerActionButton> createState() =>
      _ComposerActionButtonState();
}

class _ComposerActionButtonState extends State<_ComposerActionButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled && !_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: AnimatedScale(
        scale: _pressed && !AppMotion.animationsDisabled(context)
            ? 0.90
            : _hovered && !AppMotion.animationsDisabled(context)
                ? 1.055
                : 1,
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: _pressed ? AppMotion.standard : AppMotion.spring,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.52,
          duration: AppMotion.resolve(context, AppMotion.fast),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.gradient == null
                  ? (widget.backgroundColor ?? Colors.transparent)
                  : null,
              gradient: widget.gradient,
              shape: BoxShape.circle,
              boxShadow: widget.boxShadow,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onTap,
                onHighlightChanged: (value) {
                  if (_pressed != value) setState(() => _pressed = value);
                },
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip?.trim() ?? '';
    if (tooltip.isNotEmpty) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCancel;

  const _ReplyPreview({super.key, required this.message, this.onCancel});

  String _previewText(BuildContext context) {
    final text = message.message.trim();
    switch (message.type) {
      case 'text':
        return text;
      case 'poll':
        return message.pollQuestion.trim().isNotEmpty
            ? message.pollQuestion.trim()
            : text;
      case 'image':
        return text.isNotEmpty ? text : 'chat.photos'.tr();
      case 'video':
        return text.isNotEmpty ? text : 'chat.video'.tr();
      case 'audio':
        return text.isNotEmpty ? text : 'chat.voice_recording'.tr();
      case 'file':
        return message.fileName?.trim().isNotEmpty == true
            ? message.fileName!.trim()
            : (text.isNotEmpty ? text : 'chat.pdf_office'.tr());
      default:
        return text.isNotEmpty ? text : 'chat.attachment.generic'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _previewText(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: context.appChatInputFill,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: BorderDirectional(
          start: BorderSide(color: context.appPrimary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.sender.trim().isNotEmpty
                      ? message.sender.trim()
                      : 'chat.unknown_sender'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.appPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: chatTextDirectionFor(previewText),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
