import 'package:flutter/material.dart';

class Responsive {
  static const double phoneBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  /// Global touch target rule (min 48x48px for touch devices)
  static const double minTouchTarget = 48.0;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < phoneBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return phone;
  }

  static int gridColumns(
    BuildContext context, {
    int phone = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    return value<int>(context, phone: phone, tablet: tablet, desktop: desktop);
  }

  /// Reusable touch target wrapper that enforces min 48x48px on phone/tablet viewports
  static Widget touchTarget(Widget child, {bool enabled = true}) {
    if (!enabled) return child;
    return Builder(
      builder: (context) {
        final compact = !isDesktop(context);
        if (!compact) return child;
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTouchTarget,
            minHeight: minTouchTarget,
          ),
          child: Center(
            child: child,
          ),
        );
      },
    );
  }

  /// Constrains max width for desktop layouts so content doesn't stretch edge-to-edge awkwardly
  static Widget constrainedWidth(
    BuildContext context,
    Widget child, {
    double maxWidth = 1200.0,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop(context) ? maxWidth : double.infinity),
        child: child,
      ),
    );
  }
}
