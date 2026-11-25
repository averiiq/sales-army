import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';

/// Regression: a cloud sync REPLACED the phone's lists with the cloud copy,
/// so records whose upload had failed were wiped (and lost for good on
/// reinstall). Records must now be kept and re-uploaded until the cloud has
/// them; only records deleted on another device are removed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String id(String x) => x;

  test('a record that never reached the cloud is kept and queued for upload', () {
    final app = AppState(loadMockData: true);
    final pending = <String>[];
    final merged = app.mergeWithCloudForTest<String>('shop', ['new_on_phone', 'a'], ['a', 'b'], id, pending);
    expect(merged, containsAll(['new_on_phone', 'a', 'b']));
    expect(pending, ['new_on_phone']);
    expect(app.seenInCloudForTest('shop:a'), isTrue);
    expect(app.seenInCloudForTest('shop:new_on_phone'), isFalse);
  });

  test('a record seen in the cloud before and now gone (deleted elsewhere) is removed', () {
    final app = AppState(loadMockData: true);
    app.mergeWithCloudForTest<String>('shop', ['a', 'b'], ['a', 'b'], id, <String>[]); // both seen
    final pending = <String>[];
    final merged = app.mergeWithCloudForTest<String>('shop', ['a', 'b'], ['a'], id, pending); // b deleted elsewhere
    expect(merged, ['a']);
    expect(pending, isEmpty);
  });

  test('an empty cloud download never deletes anything (could be a network error)', () {
    final app = AppState(loadMockData: true);
    app.mergeWithCloudForTest<String>('product', ['p1'], ['p1'], id, <String>[]); // p1 seen
    final pending = <String>[];
    final merged = app.mergeWithCloudForTest<String>('product', ['p1', 'p2'], <String>[], id, pending);
    expect(merged, isNull, reason: 'phone list must be left as it is');
    expect(pending, ['p2'], reason: 'p2 never reached the cloud: upload it');
  });

  test('after an upload shows up in the cloud it is no longer pending', () {
    final app = AppState(loadMockData: true);
    final first = <String>[];
    app.mergeWithCloudForTest<String>('order', ['o1', 'x'], ['x'], id, first);
    expect(first, ['o1']);
    final second = <String>[];
    final merged = app.mergeWithCloudForTest<String>('order', ['o1', 'x'], ['o1', 'x'], id, second);
    expect(second, isEmpty);
    expect(merged, containsAll(['o1', 'x']));
    expect(merged!.length, 2, reason: 'no duplicates');
  });
}
