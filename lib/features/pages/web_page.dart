import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class WebPage extends StatefulWidget {
  final String url;

  const WebPage({super.key, required this.url});

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController controller;
  late final Uri initialUri;

  bool isLoading = true;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  static const _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
  };

  @override
  void initState() {
    super.initState();

    initialUri = Uri.parse(widget.url.trim());

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: (_) => _finishLoading(),
          onWebResourceError: (_) => _finishLoading(),
          onHttpError: (_) => _finishLoading(),
        ),
      )
      ..loadRequest(initialUri, headers: _headers);
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    if (_isAllowedPortalUri(uri)) {
      return NavigationDecision.navigate;
    }

    if (_canOpenExternally(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return NavigationDecision.prevent;
  }

  bool _isAllowedPortalUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final isUniversityHost =
        host == 'wpu.edu.sy' || host.endsWith('.wpu.edu.sy');

    return isUniversityHost && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _canOpenExternally(Uri uri) {
    return uri.scheme == 'mailto' || uri.scheme == 'tel';
  }

  void _finishLoading() {
    if (!mounted || !isLoading) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      useBackground: false,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 10,
        title: _PortalTitle(
          host: initialUri.host,
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                child: isLoading
                    ? AppStatusChip(
                        key: ValueKey(isLoading),
                        label: 'common.loading'.tr(),
                        leading: const AppLoader.inline(size: 14, strokeWidth: 2),
                        color: AppColors.primary,
                        backgroundColor: AppColors.primarySoft,
                        showBorder: false,
                      )
                    : AppStatusChip(
                        key: ValueKey(isLoading),
                        icon: Icons.check_circle_rounded,
                        label: 'common.ready'.tr(),
                        color: AppColors.success,
                        backgroundColor: AppColors.successSoft,
                        showBorder: false,
                      ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: isLoading
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox(height: 3),
        ),
      ),
      body: Stack(
        children: [
          const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(),
          ),
          WebViewWidget(controller: controller),
          if (isLoading) const _LoadingOverlay(),
        ],
      ),
    );
  }
}

class _PortalTitle extends StatelessWidget {
  final String host;
  const _PortalTitle({
    required this.host,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppBranding.portalTitle.tr(),
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          host,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: AppSurface.card(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              color: context.appCardColorStrong,
              borderColor: context.appBorder,
              borderRadius: AppDecorations.radius(AppRadii.lg),
              boxShadow: context.isDark ? const [] : AppShadows.subtle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoader.inline(size: 34, strokeWidth: 3),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'web.opening_portal'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
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
