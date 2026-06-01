import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:offnote/article_snapshot_store.dart';
import 'package:offnote/main.dart';
import 'package:offnote/save_queue.dart';

void main() {
  testWidgets('shows loading state then live altitude in the dial only', (
    tester,
  ) async {
    final service = _FakeAltitudeLocationClient();
    final rotation = StreamController<double>(sync: true);

    await tester.pumpWidget(
      MaterialApp(
        home: AltitudePage(
          locationClient: service,
          rotationTurns: rotation.stream,
          clock: () => DateTime(2026, 6, 1, 8, 30),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('获取海拔中'), findsOneWidget);

    service.add(
      const AltitudeReading(
        altitudeMeters: 367,
        latitude: 31.2333,
        longitude: 121.4833,
        accuracyMeters: 8,
        isNetworkAvailable: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('367 米'), findsOneWidget);
    expect(find.text('获取海拔中'), findsNothing);
    expect(find.textContaining('北纬'), findsNothing);
    expect(find.textContaining('东经'), findsNothing);
    expect(find.textContaining('定位中'), findsNothing);
  });

  testWidgets('rotates foreground from motion stream', (tester) async {
    final service = _FakeAltitudeLocationClient();
    final rotation = StreamController<double>(sync: true);

    await tester.pumpWidget(
      MaterialApp(
        home: AltitudePage(
          locationClient: service,
          rotationTurns: rotation.stream,
          clock: () => DateTime(2026, 6, 1, 8, 30),
        ),
      ),
    );
    await tester.pump();

    rotation.add(0.25);
    await tester.pump();

    final animatedRotation = tester.widget<AnimatedRotation>(
      find.byKey(const ValueKey('altitude-rotating-face')),
    );
    expect(animatedRotation.turns, 0.25);
  });

  testWidgets('prefers terrain elevation over device altitude when available', (
    tester,
  ) async {
    final service = _FakeAltitudeLocationClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AltitudePage(
          locationClient: service,
          rotationTurns: const Stream<double>.empty(),
          clock: () => DateTime(2026, 6, 1, 8, 30),
        ),
      ),
    );
    await tester.pump();

    service.add(
      const AltitudeReading(
        altitudeMeters: 6,
        terrainAltitudeMeters: 128,
        latitude: 31.2333,
        longitude: 121.4833,
        accuracyMeters: 8,
        isNetworkAvailable: true,
      ),
    );
    await tester.pump();

    expect(find.text('128 米'), findsOneWidget);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('prefers barometric altitude over terrain and device altitude', (
    tester,
  ) async {
    final service = _FakeAltitudeLocationClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AltitudePage(
          locationClient: service,
          rotationTurns: const Stream<double>.empty(),
          clock: () => DateTime(2026, 6, 1, 8, 30),
        ),
      ),
    );
    await tester.pump();

    service.add(
      const AltitudeReading(
        altitudeMeters: 6,
        terrainAltitudeMeters: 8,
        barometricAltitudeMeters: 126,
        latitude: 31.2333,
        longitude: 121.4833,
        accuracyMeters: 8,
        isNetworkAvailable: true,
      ),
    );
    await tester.pump();

    expect(find.text('126 米'), findsOneWidget);
    expect(find.text('8'), findsNothing);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('altitude page scrolls instead of overflowing on short screens', (
    tester,
  ) async {
    final service = _FakeAltitudeLocationClient();
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AltitudePage(
          locationClient: service,
          rotationTurns: const Stream<double>.empty(),
          clock: () => DateTime(2026, 6, 1, 8, 30),
        ),
      ),
    );
    await tester.pump();

    service.add(
      const AltitudeReading(
        altitudeMeters: 126,
        latitude: 31.2333,
        longitude: 121.4833,
        accuracyMeters: 8,
        isNetworkAvailable: false,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  test('altitude layout spec keeps dial size proportional', () {
    final regular = AltitudeLayoutSpec.forSize(const Size(390, 760));
    final short = AltitudeLayoutSpec.forSize(const Size(390, 520));

    expect(regular.dialSize, inInclusiveRange(318, 352));
    expect(short.dialSize, inInclusiveRange(278, 318));
    expect(regular.valueFontSize, inInclusiveRange(78, 88));
    expect(short.valueFontSize, lessThan(regular.valueFontSize));
    expect(regular.valueMaxWidth, lessThan(regular.dialSize * 0.65));
  });

  test('builds open meteo elevation uri for coordinate lookup', () {
    final uri = openMeteoElevationUri(latitude: 31.2333, longitude: 121.4833);

    expect(uri.scheme, 'https');
    expect(uri.host, 'api.open-meteo.com');
    expect(uri.path, '/v1/elevation');
    expect(uri.queryParameters['latitude'], '31.2333');
    expect(uri.queryParameters['longitude'], '121.4833');
  });

  test('builds open meteo pressure uri for coordinate lookup', () {
    final uri = openMeteoPressureUri(latitude: 31.2333, longitude: 121.4833);

    expect(uri.scheme, 'https');
    expect(uri.host, 'api.open-meteo.com');
    expect(uri.path, '/v1/forecast');
    expect(uri.queryParameters['latitude'], '31.2333');
    expect(uri.queryParameters['longitude'], '121.4833');
    expect(uri.queryParameters['current'], 'pressure_msl');
  });

  test(
    'calculates barometric altitude from pressure and sea-level pressure',
    () {
      expect(
        barometricAltitudeMeters(
          pressureHpa: 1000,
          seaLevelPressureHpa: 1013.25,
        ).round(),
        111,
      );
    },
  );

  test('altitude pressure color darkens with elevation', () {
    expect(altitudePressureColor(-10), const Color(0xffffb332));
    expect(altitudePressureColor(1200), const Color(0xffff6f23));
    expect(altitudePressureColor(3200), const Color(0xff8f1736));
    expect(altitudePressureColor(5200), const Color(0xff32142f));
  });

  test('android location settings request MSL altitude', () {
    final settings = altitudeLocationSettings(TargetPlatform.android);

    expect(settings, isA<AndroidSettings>());
    expect((settings as AndroidSettings).useMSLAltitude, isTrue);
    expect(settings.accuracy, LocationAccuracy.best);
  });

  testWidgets('settings keeps category management after nav move', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          store: ArticleSnapshotStore(),
          queue: SaveQueueController(
            worker: (_) async => throw UnimplementedError(),
          ),
          onChanged: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('管理文章分类文件夹'), findsOneWidget);
  });

  testWidgets('settings opens full screen altitude entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          store: ArticleSnapshotStore(),
          queue: SaveQueueController(
            worker: (_) async => throw UnimplementedError(),
          ),
          onChanged: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('实时高度表'), findsOneWidget);
    expect(find.text('全屏高度表、气压和位置'), findsOneWidget);
  });
}

class _FakeAltitudeLocationClient implements AltitudeLocationClient {
  final _controller = StreamController<AltitudeReading>(sync: true);

  void add(AltitudeReading reading) => _controller.add(reading);

  @override
  Stream<AltitudeReading> watch() => _controller.stream;
}
