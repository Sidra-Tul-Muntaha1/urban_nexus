import 'package:flutter/foundation.dart';

/// Represents the two top-level navigation modes of UrbanNexus.
enum AppView { smartCity, commercialRoi }

/// Central state provider for top-level navigation.
///
/// Consumed by [AppShell] to switch between views and by the
/// bottom navigation bar to reflect the active selection.
class AppState extends ChangeNotifier {
  AppView _currentView = AppView.smartCity;

  AppView get currentView => _currentView;

  /// Zero-based index matching the order in [AppView.values].
  int get currentIndex => _currentView.index;

  /// Switch to a given [AppView] and notify listeners.
  void navigateTo(AppView view) {
    if (_currentView == view) return;
    _currentView = view;
    notifyListeners();
  }

  /// Convenience method for [BottomNavigationBar.onTap] callbacks.
  void setIndex(int index) {
    assert(index >= 0 && index < AppView.values.length,
        'Index $index out of range for AppView');
    navigateTo(AppView.values[index]);
  }
}
