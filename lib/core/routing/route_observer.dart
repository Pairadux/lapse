import 'package:flutter/widgets.dart';

/// Global route observer for [RouteAware] subscriptions.
///
/// Registered with GoRouter so that screens can defer work until they are
/// the visible (top-most) route, and reload data when a child route pops.
final routeObserver = RouteObserver<ModalRoute<void>>();
