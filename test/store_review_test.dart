// طلب التقييم: يُعرض بعد إتمام فصل، ولا يُعرض أبدا بعد أن يقيّم اللاعب.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/store_links.dart';
import 'package:huruf/core/store_review.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('روابط التقييم', () {
    test('أندرويد: تطبيق المتجر أولا ثم الويب، وكلاهما يحمل معرّف الحزمة', () {
      final urls = StoreReview.urlsFor(isIOS: false);
      expect(urls.first, startsWith('market://'));
      expect(urls.first, contains(StoreLinks.androidPackage));
      expect(urls.last, StoreLinks.play);
    });

    test('iOS: أول رابط يفتح كتابة التقييم مباشرة لا صفحة التطبيق', () {
      final urls = StoreReview.urlsFor(isIOS: true);
      expect(urls.first, contains('action=write-review'));
      expect(urls.first, startsWith(StoreLinks.appStore));
      expect(urls.last, StoreLinks.appStore);
    });

    test('لكل منصّة رابط احتياطي واحد على الأقل', () {
      expect(StoreReview.urlsFor(isIOS: true).length, greaterThanOrEqualTo(2));
      expect(StoreReview.urlsFor(isIOS: false).length, greaterThanOrEqualTo(2));
    });
  });

  group('حالة «قيّم التطبيق»', () {
    test('لاعب جديد لم يقيّم بعد', () async {
      final c = await _container();
      expect(c.read(appRatedProvider), isFalse);
    });

    test('المحفوظ يُقرأ عند الإقلاع: من قيّم لا يُسأل ثانية', () async {
      final c = await _container({'app_rated': true});
      expect(c.read(appRatedProvider), isTrue);
    });

    test('فتح المتجر يعلّم اللاعب مقيّما ويُحفظ فورا', () async {
      final c = await _container();
      // لا إضافة منصّة في بيئة الاختبار، فالفتح يفشل — والعلامة تُوضع
      // مع ذلك عمدا: اللاعب أبدى موقفه بالضغط، وفشل تقني ليس خطأه
      await c.read(appRatedProvider.notifier).openStoreAndMark();
      expect(c.read(appRatedProvider), isTrue);
      expect(c.read(progressStoreProvider).appRated, isTrue);
    });
  });
}
