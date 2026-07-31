import 'package:flutter/material.dart';

import '../screens/upload_screen.dart';

/// Tracks the app's navigation stack so flow routes can be removed without
/// animating through each one on the way back to the home route.
class AppNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  List<Route<dynamic>> routesFor(NavigatorState navigator) =>
      _routes.where((route) => identical(route.navigator, navigator)).toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) _routes.add(newRoute);
  }
}

final appNavigatorObserver = AppNavigatorObserver();

/// Removes intermediate flow routes, then pops the current page once.
///
/// The remaining pop uses the platform's native back transition, so the
/// current page slides away and exposes the existing home page underneath.
void returnToHome(BuildContext context) {
  final navigator = Navigator.of(context);
  final currentRoute = ModalRoute.of(context);
  if (currentRoute == null) return;

  final routes = appNavigatorObserver.routesFor(navigator);
  final homeRoute = routes.where((route) => route.isFirst).firstOrNull;
  if (homeRoute == null || !routes.contains(currentRoute)) {
    // A hot reload can add the observer after the navigator already has
    // routes, so it has not received their didPush callbacks yet. Fall back
    // to a direct replacement instead of leaving the back action inert.
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const UploadScreen()),
      (_) => false,
    );
    return;
  }

  for (final route in routes) {
    if (!identical(route, homeRoute) && !identical(route, currentRoute)) {
      navigator.removeRoute(route);
    }
  }
  navigator.pop();
}
