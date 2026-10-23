import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';
import 'package:gromore_flutter/src/ad_size_cache.dart';

class SizePlatform extends GromoreFlutterPlatform {
  final events = StreamController<dynamic>.broadcast(sync: true);
  int nextId = 0;
  @override
  Stream<dynamic> get adEvents => events.stream;
  @override
  Stream<dynamic> get logEvents => const Stream.empty();
  @override
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    final id = 'size-${nextId++}';
    events.add({
      'adId': id,
      'adType': type.value,
      'eventType': 'loaded',
      'data': {
        'adIds': [id, if (type != GromoreAdType.banner) '$id-child']
      },
    });
    return id;
  }

  @override
  Future<void> disposeAd(String adId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = SizePlatform();
  setUpAll(() async {
    GromoreFlutterPlatform.instance = platform;
    final subscription = GromoreFlutter.instance.listenAdEvents(
      callback: const GromoreAdCallback(),
    );
    await subscription.cancel();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> withDesktopView(Future<void> Function() action) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await action();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Widget page(Widget child) => MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      );

  for (final type in [
    GromoreAdType.banner,
    GromoreAdType.native,
    GromoreAdType.drawNative
  ]) {
    testWidgets(
        '${type.value} reuses Config size for every loaded instance',
        (tester) => withDesktopView(() async {
              final GromoreAdConfig config;
              switch (type) {
                case GromoreAdType.banner:
                  config = const GromoreBannerConfig(
                      placementId: 'b', width: 320.5, height: 100.25);
                  break;
                case GromoreAdType.native:
                  config = const GromoreFeedConfig(
                      placementId: 'f', width: 320.5, height: 100.25);
                  break;
                default:
                  config = const GromoreDrawConfig(
                      placementId: 'd', width: 320.5, height: 100.25);
              }
              final ids = (await tester.runAsync(() =>
                  GromoreFlutter.instance.loadAds(type, config.toRequest())))!;
              for (final id in ids) {
                final Widget view;
                switch (type) {
                  case GromoreAdType.banner:
                    view = GromoreBannerView(adId: id, enableVisibility: false);
                    break;
                  case GromoreAdType.native:
                    view = GromoreFeedView(adId: id, enableVisibility: false);
                    break;
                  default:
                    view = GromoreDrawView(adId: id, enableVisibility: false);
                }
                await tester.pumpWidget(page(view));
                expect(tester.getSize(find.byType(GromoreAdView)),
                    const Size(320.5, 100.25));
              }
              await tester.pumpWidget(const SizedBox.shrink());
              for (final id in ids) {
                await GromoreFlutter.instance.disposeAd(id);
              }
            }));
  }

  testWidgets(
      'View overrides each dimension without modifying Config defaults',
      (tester) => withDesktopView(() async {
            final id = await GromoreBanner.load(const GromoreBannerConfig(
              placementId: 'b',
              width: 320,
              height: 100,
            ));
            for (final dimensions in [
              [360.0, null, const Size(360, 100)],
              [null, 120.0, const Size(320, 120)],
              [360.0, 120.0, const Size(360, 120)],
              [null, null, const Size(320, 100)],
            ]) {
              await tester.pumpWidget(page(GromoreBannerView(
                adId: id,
                width: dimensions[0] as double?,
                height: dimensions[1] as double?,
                enableVisibility: false,
              )));
              expect(tester.getSize(find.byType(GromoreAdView)), dimensions[2]);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await GromoreBanner.dispose(id);
            expect(
                () => AdSizeCache.resolve(id, null, null, devicePixelRatio: 1),
                throwsFlutterError);
          }));

  test(
      'native Android sizes convert to logical sizes; explicit View sizes stay logical',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final id = await GromoreBanner.load(const GromoreBannerConfig(
      placementId: 'b',
      width: 960,
      height: 300,
      options: GromoreRequestOptions(sizeUnit: GromoreAdSizeUnit.nativePixels),
    ));
    expect(AdSizeCache.resolve(id, null, null, devicePixelRatio: 3),
        const Size(320, 100));
    expect(AdSizeCache.resolve(id, 360, null, devicePixelRatio: 3),
        const Size(360, 100));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AdSizeCache.resolve(id, null, null, devicePixelRatio: 3),
        const Size(960, 300));
    await GromoreBanner.dispose(id);
  });

  test(
      'missing dimensions require View values; request precedence matches native',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final id = await GromoreBanner.load(const GromoreBannerConfig(
      placementId: 'b',
      width: 320,
      extra: {'width': 330},
      androidExtra: {'width': 340},
    ));
    expect(() => AdSizeCache.resolve(id, null, null, devicePixelRatio: 3),
        throwsFlutterError);
    expect(AdSizeCache.resolve(id, null, 100, devicePixelRatio: 3),
        const Size(330, 100));
    expect(AdSizeCache.resolve('external-id', 360, 120, devicePixelRatio: 3),
        const Size(360, 120));
    await GromoreBanner.dispose(id);
  });
}
