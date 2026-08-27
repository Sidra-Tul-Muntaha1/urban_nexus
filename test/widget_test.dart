import 'package:flutter_test/flutter_test.dart';
import 'package:urban_nexus/models/app_state.dart';

void main() {
  group('AppState tests', () {
    test('AppState initial state is Smart City (index 0)', () {
      final state = AppState();
      expect(state.currentIndex, equals(0));
      expect(state.currentView, equals(AppView.smartCity));
    });

    test('AppState switches to Commercial ROI (index 1)', () {
      final state = AppState();
      state.setIndex(1);
      expect(state.currentIndex, equals(1));
      expect(state.currentView, equals(AppView.commercialRoi));
    });
  });
}
