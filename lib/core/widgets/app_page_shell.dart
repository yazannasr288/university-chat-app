import 'package:flutter/material.dart';

import 'app_motion_widgets.dart';
import 'app_scaffold_background.dart';

class AppPageShell extends StatelessWidget {
  final String? title;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;
  final Widget body;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final bool useBackground;
  final bool animateBackground;
  final bool animateBody;
  final bool safeArea;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const AppPageShell({
    super.key,
    this.title,
    this.appBar,
    this.actions,
    required this.body,
    this.scaffoldKey,
    this.drawer,
    this.endDrawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.useBackground = true,
    this.animateBackground = false,
    this.animateBody = true,
    this.safeArea = false,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (safeArea) {
      content = SafeArea(child: content);
    }

    if (animateBody) {
      content = AppPageEntrance(child: content);
    }

    if (useBackground) {
      content = AppScaffoldBackground(
        animate: animateBackground,
        child: content,
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      appBar:
          appBar ??
          (title == null
              ? null
              : AppBar(
                title: Text(title!),
                centerTitle: centerTitle,
                automaticallyImplyLeading: automaticallyImplyLeading,
                actions: actions,
              )),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      body: content,
    );
  }
}
