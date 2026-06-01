part of '../main.dart';

class AltitudeReading {
  const AltitudeReading({
    required this.altitudeMeters,
    this.terrainAltitudeMeters,
    this.barometricAltitudeMeters,
    this.pressureHpa,
    this.speedMetersPerSecond,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isNetworkAvailable,
  });

  final double altitudeMeters;
  final double? terrainAltitudeMeters;
  final double? barometricAltitudeMeters;
  final double? pressureHpa;
  final double? speedMetersPerSecond;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isNetworkAvailable;

  double get displayAltitudeMeters =>
      barometricAltitudeMeters ?? terrainAltitudeMeters ?? altitudeMeters;

  bool get isTerrainCorrected => terrainAltitudeMeters != null;

  bool get isBarometricCorrected => barometricAltitudeMeters != null;
}

abstract class AltitudeLocationClient {
  Stream<AltitudeReading> watch();
}

abstract class TerrainElevationClient {
  Future<double?> lookup({required double latitude, required double longitude});
}

abstract class WeatherPressureClient {
  Future<double?> lookupSeaLevelPressure({
    required double latitude,
    required double longitude,
  });
}

Uri openMeteoElevationUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('api.open-meteo.com', '/v1/elevation', {
    'latitude': latitude.toStringAsFixed(4),
    'longitude': longitude.toStringAsFixed(4),
  });
}

Uri openMeteoPressureUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': latitude.toStringAsFixed(4),
    'longitude': longitude.toStringAsFixed(4),
    'current': 'pressure_msl',
  });
}

double barometricAltitudeMeters({
  required double pressureHpa,
  required double seaLevelPressureHpa,
}) {
  return (44330 * (1 - math.pow(pressureHpa / seaLevelPressureHpa, 0.1903)))
      .toDouble();
}

class OpenMeteoTerrainElevationClient implements TerrainElevationClient {
  OpenMeteoTerrainElevationClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<double?> lookup({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.getUri<Map<String, Object?>>(
      openMeteoElevationUri(latitude: latitude, longitude: longitude),
    );
    final elevations = response.data?['elevation'];
    if (elevations is List && elevations.isNotEmpty) {
      final value = elevations.first;
      if (value is num) {
        return value.toDouble();
      }
    }
    return null;
  }
}

class OpenMeteoWeatherPressureClient implements WeatherPressureClient {
  OpenMeteoWeatherPressureClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<double?> lookupSeaLevelPressure({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.getUri<Map<String, Object?>>(
      openMeteoPressureUri(latitude: latitude, longitude: longitude),
    );
    final current = response.data?['current'];
    if (current is Map<String, Object?>) {
      final pressure = current['pressure_msl'];
      if (pressure is num) {
        return pressure.toDouble();
      }
    }
    return null;
  }
}

class AltitudeLocationException implements Exception {
  const AltitudeLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeolocatorAltitudeLocationClient implements AltitudeLocationClient {
  GeolocatorAltitudeLocationClient({
    GeolocatorPlatform? geolocator,
    Connectivity? connectivity,
    TerrainElevationClient? terrainElevationClient,
    WeatherPressureClient? weatherPressureClient,
    Stream<BarometerEvent>? barometerEvents,
  }) : _geolocator = geolocator ?? GeolocatorPlatform.instance,
       _connectivity = connectivity ?? Connectivity(),
       _terrainElevationClient =
           terrainElevationClient ?? OpenMeteoTerrainElevationClient(),
       _weatherPressureClient =
           weatherPressureClient ?? OpenMeteoWeatherPressureClient(),
       _barometerEvents =
           barometerEvents ??
           barometerEventStream(samplingPeriod: SensorInterval.normalInterval);

  final GeolocatorPlatform _geolocator;
  final Connectivity _connectivity;
  final TerrainElevationClient _terrainElevationClient;
  final WeatherPressureClient _weatherPressureClient;
  final Stream<BarometerEvent> _barometerEvents;
  final _terrainCache = <String, double>{};
  final _pressureCache = <String, double>{};
  double? _latestPressureHpa;

  @override
  Stream<AltitudeReading> watch() async* {
    final enabled = await _geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const AltitudeLocationException('定位服务未开启');
    }

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AltitudeLocationException('需要位置权限才能获取海拔');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AltitudeLocationException('位置权限已关闭，请到系统设置开启');
    }

    var networkAvailable = await _hasNetwork();
    final connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => networkAvailable = _resultsHaveNetwork(results),
    );
    final barometerSubscription = _barometerEvents.listen(
      (event) => _latestPressureHpa = event.pressure,
      onError: (Object error) {
        debugPrint('Barometer stream failed: $error');
      },
    );

    try {
      await for (final position in _geolocator.getPositionStream(
        locationSettings: altitudeLocationSettings(defaultTargetPlatform),
      )) {
        final baseReading = AltitudeReading(
          altitudeMeters: position.altitude,
          pressureHpa: _latestPressureHpa,
          speedMetersPerSecond: position.speed.isFinite ? position.speed : null,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          isNetworkAvailable: networkAvailable,
        );
        yield baseReading;

        if (!networkAvailable) {
          continue;
        }

        final terrainAltitude = await _lookupTerrainAltitude(position);
        final barometricAltitude = await _lookupBarometricAltitude(position);
        if (terrainAltitude == null && barometricAltitude == null) {
          continue;
        }
        yield AltitudeReading(
          altitudeMeters: position.altitude,
          terrainAltitudeMeters: terrainAltitude,
          barometricAltitudeMeters: barometricAltitude,
          pressureHpa: _latestPressureHpa,
          speedMetersPerSecond: position.speed.isFinite ? position.speed : null,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          isNetworkAvailable: networkAvailable,
        );
      }
    } finally {
      await connectivitySubscription.cancel();
      await barometerSubscription.cancel();
    }
  }

  Future<double?> _lookupTerrainAltitude(Position position) async {
    final key =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';
    final cached = _terrainCache[key];
    if (cached != null) {
      return cached;
    }
    try {
      final elevation = await _terrainElevationClient
          .lookup(latitude: position.latitude, longitude: position.longitude)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (elevation != null) {
        _terrainCache[key] = elevation;
      }
      return elevation;
    } catch (error) {
      debugPrint('Terrain elevation lookup failed: $error');
      return null;
    }
  }

  Future<double?> _lookupBarometricAltitude(Position position) async {
    final pressureHpa = _latestPressureHpa;
    if (pressureHpa == null || pressureHpa <= 0) {
      return null;
    }
    final key =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';
    var seaLevelPressureHpa = _pressureCache[key];
    if (seaLevelPressureHpa == null) {
      try {
        seaLevelPressureHpa = await _weatherPressureClient
            .lookupSeaLevelPressure(
              latitude: position.latitude,
              longitude: position.longitude,
            )
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
        if (seaLevelPressureHpa != null) {
          _pressureCache[key] = seaLevelPressureHpa;
        }
      } catch (error) {
        debugPrint('Weather pressure lookup failed: $error');
        return null;
      }
    }
    if (seaLevelPressureHpa == null || seaLevelPressureHpa <= 0) {
      return null;
    }
    return barometricAltitudeMeters(
      pressureHpa: pressureHpa,
      seaLevelPressureHpa: seaLevelPressureHpa,
    );
  }

  Future<bool> _hasNetwork() async {
    return _resultsHaveNetwork(await _connectivity.checkConnectivity());
  }

  bool _resultsHaveNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

LocationSettings altitudeLocationSettings(TargetPlatform platform) {
  if (platform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
      useMSLAltitude: true,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 1,
  );
}

Color altitudePressureColor(double altitudeMeters) {
  if (altitudeMeters < 500) {
    return const Color(0xffffb332);
  }
  if (altitudeMeters < 2000) {
    return const Color(0xffff6f23);
  }
  if (altitudeMeters < 4000) {
    return const Color(0xff8f1736);
  }
  return const Color(0xff32142f);
}

class AltitudeLayoutSpec {
  const AltitudeLayoutSpec({
    required this.compact,
    required this.pagePadding,
    required this.topGap,
    required this.telemetryGap,
    required this.coordGap,
    required this.sectionGap,
    required this.dialSize,
    required this.dialPadding,
    required this.titleIconSize,
    required this.titleFontSize,
    required this.valueFontSize,
    required this.unitFontSize,
    required this.valueMaxWidth,
    required this.metaIconSize,
    required this.metaTitleSize,
    required this.metaLineSize,
    required this.statusFontSize,
    required this.statusIconSize,
    required this.statusHPadding,
    required this.statusVPadding,
    required this.metaDividerHeight,
    required this.telemetryFontSize,
    required this.coordFontSize,
  });

  factory AltitudeLayoutSpec.forSize(Size size) {
    final compact = size.height < 640;
    final shortest = size.shortestSide;
    final dialSize = (shortest * (compact ? 0.76 : 0.86)).clamp(
      compact ? 278.0 : 318.0,
      compact ? 318.0 : 352.0,
    );
    return AltitudeLayoutSpec(
      compact: compact,
      pagePadding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 18 : 24,
        compact ? 18 : 24,
        compact ? 18 : 24,
      ),
      topGap: compact ? 10 : 20,
      telemetryGap: compact ? 46 : 82,
      coordGap: compact ? 44 : 88,
      sectionGap: compact ? 12 : 22,
      dialSize: dialSize,
      dialPadding: compact ? 24 : 30,
      titleIconSize: compact ? 26 : 34,
      titleFontSize: compact ? 22 : 28,
      valueFontSize: compact ? 70 : 82,
      unitFontSize: compact ? 22 : 26,
      valueMaxWidth: dialSize - (compact ? 116 : 132),
      metaIconSize: compact ? 26 : 34,
      metaTitleSize: compact ? 15 : 18,
      metaLineSize: compact ? 13 : 16,
      statusFontSize: compact ? 14 : 16,
      statusIconSize: compact ? 18 : 20,
      statusHPadding: compact ? 16 : 22,
      statusVPadding: compact ? 9 : 12,
      metaDividerHeight: compact ? 70 : 84,
      telemetryFontSize: compact ? 19 : 24,
      coordFontSize: compact ? 24 : 34,
    );
  }

  final bool compact;
  final EdgeInsets pagePadding;
  final double topGap;
  final double telemetryGap;
  final double coordGap;
  final double sectionGap;
  final double dialSize;
  final double dialPadding;
  final double titleIconSize;
  final double titleFontSize;
  final double valueFontSize;
  final double unitFontSize;
  final double valueMaxWidth;
  final double metaIconSize;
  final double metaTitleSize;
  final double metaLineSize;
  final double statusFontSize;
  final double statusIconSize;
  final double statusHPadding;
  final double statusVPadding;
  final double metaDividerHeight;
  final double telemetryFontSize;
  final double coordFontSize;
}

class AltitudePage extends StatefulWidget {
  const AltitudePage({
    super.key,
    AltitudeLocationClient? locationClient,
    Stream<double>? rotationTurns,
    DateTime Function()? clock,
  }) : _locationClient = locationClient,
       _rotationTurns = rotationTurns,
       _clock = clock;

  final AltitudeLocationClient? _locationClient;
  final Stream<double>? _rotationTurns;
  final DateTime Function()? _clock;

  @override
  State<AltitudePage> createState() => _AltitudePageState();
}

class _AltitudePageState extends State<AltitudePage> {
  late final AltitudeLocationClient _locationClient =
      widget._locationClient ?? GeolocatorAltitudeLocationClient();
  late final DateTime Function() _clock = widget._clock ?? DateTime.now;
  StreamSubscription<AltitudeReading>? _subscription;
  StreamSubscription<double>? _rotationSubscription;
  Timer? _clockTimer;
  AltitudeReading? _reading;
  DateTime lateNow = DateTime.now();
  bool _hasError = false;
  double _rotationTurns = 0;

  @override
  void initState() {
    super.initState();
    lateNow = _clock();
    _watchAltitude();
    _watchRotation();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _rotationSubscription?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _watchRotation() {
    final stream =
        widget._rotationTurns ??
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).map(accelerometerRotationTurns);
    _rotationSubscription = stream.listen(
      (turns) {
        if (!mounted) {
          return;
        }
        setState(() => _rotationTurns = turns);
      },
      onError: (Object error) {
        debugPrint('Altitude rotation stream failed: $error');
      },
    );
  }

  void _watchAltitude() {
    setState(() {
      _hasError = false;
    });
    _subscription = _locationClient.watch().listen(
      (reading) {
        if (!mounted) {
          return;
        }
        setState(() {
          _reading = reading;
          _hasError = false;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _hasError = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final altitude = reading?.displayAltitudeMeters.round();
    final pressureColor = altitudePressureColor(
      reading?.displayAltitudeMeters ?? 0,
    );
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff1396df),
              Color(0xff69c3ed),
              Color(0xffffc06d),
              Color(0xff0b1f3b),
            ],
            stops: [0, 0.42, 0.7, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spec = AltitudeLayoutSpec.forSize(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
              return SingleChildScrollView(
                padding: spec.pagePadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - spec.pagePadding.vertical,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedRotation(
                        key: const ValueKey('altitude-rotating-face'),
                        turns: _rotationTurns,
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AltitudeDial(
                              altitude: altitude,
                              loading: reading == null && !_hasError,
                              hasError: _hasError,
                              pressureColor: pressureColor,
                              spec: spec,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double accelerometerRotationTurns(AccelerometerEvent event) {
  if (event.x == 0 && event.y == 0) {
    return 0;
  }
  return math.atan2(event.x, event.y) / (math.pi * 2);
}

class _AltitudeDial extends StatelessWidget {
  const _AltitudeDial({
    required this.altitude,
    required this.loading,
    required this.hasError,
    required this.pressureColor,
    required this.spec,
  });

  final int? altitude;
  final bool loading;
  final bool hasError;
  final Color pressureColor;
  final AltitudeLayoutSpec spec;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: spec.dialSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.34),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: pressureColor.withValues(alpha: 0.32),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _AltitudeDialRingPainter(
                color: pressureColor,
                progress: loading ? 0.18 : 0.82,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spec.dialPadding),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.28, -0.36),
                  radius: 0.96,
                  colors: [
                    Color.lerp(const Color(0xffffd66d), pressureColor, 0.15)!,
                    Color.lerp(const Color(0xffff7a22), pressureColor, 0.46)!,
                    pressureColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(spec.compact ? 18 : 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: loading
                        ? _AltitudeLoading(spec: spec)
                        : _AltitudeValue(
                            key: ValueKey(altitude),
                            altitude: altitude,
                            hasError: hasError,
                            spec: spec,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AltitudeLoading extends StatelessWidget {
  const _AltitudeLoading({required this.spec});

  final AltitudeLayoutSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: spec.compact ? 30 : 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '获取海拔中',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: spec.metaTitleSize + 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AltitudeValue extends StatelessWidget {
  const _AltitudeValue({
    super.key,
    required this.altitude,
    required this.hasError,
    required this.spec,
  });

  final int? altitude;
  final bool hasError;
  final AltitudeLayoutSpec spec;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Text(
        '无法获取',
        style: TextStyle(
          color: Colors.white,
          fontSize: spec.unitFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '当前海拔',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: spec.metaTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spec.valueMaxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              altitude == null ? '-- 米' : '$altitude 米',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: spec.valueFontSize,
                height: 0.96,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AltitudeDialRingPainter extends CustomPainter {
  const _AltitudeDialRingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, basePaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Colors.white.withValues(alpha: 0.52),
          color.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.52),
        ],
      ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      arcPaint,
    );

    final glossPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.5),
        radius: 0.58,
        colors: [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, size.shortestSide / 2, glossPaint);
  }

  @override
  bool shouldRepaint(covariant _AltitudeDialRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
