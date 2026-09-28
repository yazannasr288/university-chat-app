import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class PinEntryView extends StatefulWidget {
  final String title;
  final String subtitle;
  final ValueChanged<String> onCompleted;
  final Widget? bottomAction;
  final int errorTick;

  const PinEntryView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCompleted,
    this.bottomAction,
    this.errorTick = 0,
  });

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onChanged);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 2),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusAndShowKeyboard();
    });
  }

  @override
  void didUpdateWidget(covariant PinEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool stepChanged =
        widget.title != oldWidget.title || widget.subtitle != oldWidget.subtitle;

    if (stepChanged) {
      _isSubmitting = false;
      _controller.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusAndShowKeyboard();
      });

      if (mounted) {
        setState(() {});
      }
    }

    if (widget.errorTick != oldWidget.errorTick) {
      _isSubmitting = false;
      _controller.clear();
      _shakeController.forward(from: 0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusAndShowKeyboard();
      });

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _focusAndShowKeyboard() {
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    Future.microtask(() {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _onChanged() {
    final digitsOnly = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly != _controller.text) {
      _controller.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
      return;
    }

    if (mounted) {
      setState(() {});
    }

    if (digitsOnly.length == 4 && !_isSubmitting) {
      _isSubmitting = true;
      final pin = digitsOnly;

      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _controller.clear();
        widget.onCompleted(pin);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 0;
    final int length = _controller.text.length.clamp(0, 4);
    final cardColor = context.appCardColor;
    final cardStrongColor = context.appCardColorStrong;
    final emptyDotColor = context.isDark ? context.appSurfaceSoft : Colors.white;
    final filledDotColor = context.appPrimary;
    final filledBorderColor = filledDotColor;

    return Directionality(
      textDirection: context.locale.languageCode == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
      child: AppPageShell(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        useBackground: false,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusAndShowKeyboard,
          child: SafeArea(
            child: AppScaffoldBackground(
              child: Stack(
                children: [
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                          child: Column(
                            children: [
                              const Spacer(),
                              AppIconBadge.circle(
                                icon: Icons.lock_outline_rounded,
                                size: 92,
                                iconSize: 46,
                                gradient: AppGradients.primary,
                                color: Colors.white,
                                boxShadow: AppShadows.floating,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: context.textTheme.headlineSmall?.copyWith(
                                  fontSize: 30,
                                  color: context.appTextPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                widget.subtitle,
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyLarge?.copyWith(
                                  color: context.appTextSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                AppBranding.appNameArabic.tr(),
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.appTextMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: keyboardOpen ? AppSpacing.md : 110,
                                ),
                                child: AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_shakeAnimation.value, 0),
                                      child: child,
                                    );
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppSurface.card(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xl,
                                          vertical: AppSpacing.lg,
                                        ),
                                        color: cardColor,
                                        borderColor: context.appBorder,
                                        borderRadius: BorderRadius.circular(AppRadii.xl),
                                        boxShadow: AppShadows.card,
                                        onTap: _focusAndShowKeyboard,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(4, (index) {
                                            final bool filled = index < length;

                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 140,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.sm,
                                              ),
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: filled
                                                    ? filledDotColor
                                                    : emptyDotColor,
                                                border: Border.all(
                                                  color: filled
                                                      ? filledBorderColor
                                                      : context.appBorderStrong,
                                                  width: 1.7,
                                                ),
                                                boxShadow: filled
                                                    ? AppShadows.subtle
                                                    : const [],
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                      if (widget.bottomAction != null) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        widget.bottomAction!,
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isSubmitting)
                    Positioned.fill(
                      child: AbsorbPointer(
                        absorbing: true,
                        child: ColoredBox(
                          color: AppColors.black.withValues(alpha: 0.18),
                          child: Center(
                            child: AppSurface.card(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              color: cardStrongColor,
                              borderColor: context.appBorder,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              boxShadow: AppShadows.card,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppLoader.inline(
                                    size: 40,
                                    strokeWidth: 3,
                                    color: context.appPrimary,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'pin.verifying'.tr(),
                                    style: context.textTheme.titleSmall?.copyWith(
                                      color: context.appTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 4,
                        showCursor: false,
                        obscureText: true,
                        obscuringCharacter: '●',
                        enableSuggestions: false,
                        autocorrect: false,
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
