// lib/src/controllers/polygon_handler.dart

part of '../mapbox_maps_flutter_draw.dart';

class PolygonHandler extends GeometryHandler {
  final MapboxDrawController _controller;

  // Private Variables
  final List<Point> _polygonPoints = []; // To store the tapped points
  final List<CircleAnnotation> _circleAnnotations = []; // Circle markers
  PolygonAnnotation? _currentPolygon;
  final List<PolygonAnnotation> polygons = [];

  // Stream for polygon points changes
  final StreamController<List<Point>> _polygonPointsController =
      StreamController<List<Point>>.broadcast();

  // Stream for polygons changes
  final StreamController<List<Polygon>> _polygonsController =
      StreamController<List<Polygon>>.broadcast();

  // Annotation Managers
  CircleAnnotationManager? _circleAnnotationManager;
  PolygonAnnotationManager? _polygonAnnotationManager;

  // Current drawing style (used when drawing a new polygon)
  Color? _currentDrawingFillColor;
  Color? _currentDrawingOutlineColor;
  double? _currentDrawingOpacity;
  Map<String, dynamic>? _currentDrawingMetadata;

  // Metadata storage (keyed by polygon annotation ID)
  final Map<String, Map<String, dynamic>> _polygonMetadata = {};

  // Initialization flag to prevent operations before managers are fully ready
  bool _isInitialized = false;

  /// Returns true if the polygon handler is fully initialized and ready for operations.
  bool get isInitialized => _isInitialized;

  Function(GeometryChangeEvent event)? onChange;

  PolygonHandler(this._controller) : super(_controller);

  /// Stream that emits whenever the polygon points change.
  Stream<List<Point>> get polygonPointsStream =>
      _polygonPointsController.stream;

  /// Stream that emits whenever the polygons change.
  Stream<List<Polygon>> get polygonsStream => _polygonsController.stream;

  /// Returns a copy of the current polygon points.
  List<Point> get polygonPoints => List.unmodifiable(_polygonPoints);

  /// Returns a copy of the current polygons.
  List<Polygon> get currentPolygons => polygons.map((e) => e.geometry).toList();

  /// Helper method to emit polygon points changes to the stream.
  void _emitPolygonPointsChange() {
    _polygonPointsController.add(List.unmodifiable(_polygonPoints));
  }

  /// Helper method to emit polygons changes to the stream.
  void _emitPolygonsChange() {
    _polygonsController.add(polygons.map((e) => e.geometry).toList());
  }

  /// Initializes polygon-related annotation managers.
  @override
  Future<void> initialize(MapboxMap mapController,
      {GeometryStyle? style,
      Function(GeometryChangeEvent event)? onChange}) async {
    this.onChange = onChange;

    _circleAnnotationManager = await mapController.annotations
        .createCircleAnnotationManager(id: 'mapbox_draw_polygon_circles');

    _circleAnnotationManager!
      ..setCircleEmissiveStrength(1)
      ..setCirclePitchAlignment(CirclePitchAlignment.MAP)
      ..setCircleColor(style?.color?.value ?? Colors.redAccent.value)
      ..setCircleStrokeColor(style?.strokeColor?.value ?? Colors.white.value)
      ..setCircleStrokeWidth(style?.strokeWidth ?? 2)
      ..setCircleRadius(style?.width ?? 6);

    _polygonAnnotationManager = await mapController.annotations
        .createPolygonAnnotationManager(below: 'mapbox_draw_polygon_circles');

    _polygonAnnotationManager!
      ..setFillEmissiveStrength(1)
      ..setFillColor(style?.color?.value ?? Colors.redAccent.value)
      ..setFillOutlineColor(style?.strokeColor?.value ?? Colors.white.value)
      ..setFillOpacity(style?.opacity ?? 0.8);

    _polygonAnnotationManager!
        .addOnPolygonAnnotationClickListener(_AnnotationClickListener(this));

    // Register PolygonHandler tap listener
    MapTapHandler().addTapListener(_onMapTapListener);

    // Small delay to ensure native-side managers are fully registered
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Mark as initialized only after everything is set up
    _isInitialized = true;
  }

  /// Adds existing polygons to the map.
  ///
  /// Each [PolygonData] can have individual fill colors, outline colors, and opacity.
  /// For polygons without custom styling, simply omit the color parameters.
  ///
  /// Example:
  /// ```dart
  /// await polygonHandler.add([
  ///   PolygonData(
  ///     polygon: myPolygon1,
  ///     fillColor: Colors.blue,
  ///     outlineColor: Colors.white,
  ///     opacity: 0.7,
  ///   ),
  ///   PolygonData(
  ///     polygon: myPolygon2,
  ///     fillColor: Colors.green,
  ///   ),
  ///   PolygonData(polygon: myPolygon3), // Uses default styling
  /// ]);
  /// ```
  Future<void> add(List<PolygonData> polygonDataList) async {
    if (!_isInitialized || _polygonAnnotationManager == null) {
      print('PolygonHandler is not fully initialized.');
      return;
    }

    await _circleAnnotationManager?.deleteAll();
    _circleAnnotations.clear();
    _polygonPoints.clear();
    _emitPolygonPointsChange();
    _currentPolygon = null;
    polygons.clear();

    for (final item in polygonDataList) {
      try {
        final annotationOption = PolygonAnnotationOptions(
          geometry: item.polygon,
          fillColor: item.fillColor?.value,
          fillOutlineColor: item.outlineColor?.value,
          fillOpacity: item.opacity,
        );

        final newPolyAnn =
            await _polygonAnnotationManager!.create(annotationOption);
        polygons.add(newPolyAnn);

        // Store metadata in our Map if provided
        if (item.metadata != null) {
          _polygonMetadata[newPolyAnn.id] = item.metadata!;
        }
      } catch (e) {
        print('Error adding polygon: $e');
      }
    }
    _emitPolygonsChange();
    _controller.notifyListeners();
  }

  /// Retrieves all polygons from the map as [PolygonData] objects.
  ///
  /// Each returned [PolygonData] includes the polygon geometry and its
  /// associated styling (fill color, outline color, opacity) and metadata.
  List<PolygonData> getAll() {
    return polygons
        .map((e) => PolygonData(
              polygon: e.geometry,
              fillColor: e.fillColor != null ? Color(e.fillColor!) : null,
              outlineColor: e.fillOutlineColor != null
                  ? Color(e.fillOutlineColor!)
                  : null,
              opacity: e.fillOpacity,
              metadata: _polygonMetadata[e.id],
            ))
        .toList();
  }

  /// Starts the polygon drawing process.
  ///
  /// Optional parameters allow you to set the color for the polygon being drawn:
  /// - [fillColor]: The fill color for the polygon
  /// - [outlineColor]: The outline/stroke color for the polygon
  /// - [opacity]: The opacity of the polygon fill (0.0 to 1.0)
  /// - [metadata]: Optional metadata to associate with the polygon
  ///
  /// Example:
  /// ```dart
  /// await polygonHandler.startDrawing(
  ///   fillColor: Colors.blue,
  ///   outlineColor: Colors.white,
  ///   opacity: 0.7,
  ///   metadata: {'name': 'Zone A', 'id': 123},
  /// );
  /// ```
  @override
  Future<void> startDrawing({
    Color? fillColor,
    Color? outlineColor,
    double? opacity,
    Map<String, dynamic>? metadata,
  }) async {
    // Set the drawing style
    _currentDrawingFillColor = fillColor;
    _currentDrawingOutlineColor = outlineColor;
    _currentDrawingOpacity = opacity;
    _currentDrawingMetadata = metadata;

    // Reset any existing drawing state
    _currentPolygon = null;
    _polygonPoints.clear();
    _emitPolygonPointsChange();
    await _circleAnnotationManager?.deleteAll();
    _circleAnnotations.clear();
    _controller.notifyListeners();
  }

  /// Sets the color for the polygon currently being drawn.
  ///
  /// This can be called at any time during the drawing process to change
  /// the color of the polygon being created.
  ///
  /// Example:
  /// ```dart
  /// polygonHandler.setDrawingStyle(
  ///   fillColor: Colors.purple,
  ///   outlineColor: Colors.yellow,
  ///   opacity: 0.6,
  ///   metadata: {'type': 'restricted'},
  /// );
  /// ```
  void setDrawingStyle({
    Color? fillColor,
    Color? outlineColor,
    double? opacity,
    Map<String, dynamic>? metadata,
  }) {
    _currentDrawingFillColor = fillColor;
    _currentDrawingOutlineColor = outlineColor;
    _currentDrawingOpacity = opacity;
    _currentDrawingMetadata = metadata;

    // Update circle annotation manager colors to match
    if (_circleAnnotationManager != null && fillColor != null) {
      _circleAnnotationManager!.setCircleColor(fillColor.value);
    }
    if (_circleAnnotationManager != null && outlineColor != null) {
      _circleAnnotationManager!.setCircleStrokeColor(outlineColor.value);
    }
  }

  /// Clears the current drawing style, reverting to default colors.
  void clearDrawingStyle() {
    _currentDrawingFillColor = null;
    _currentDrawingOutlineColor = null;
    _currentDrawingOpacity = null;
    _currentDrawingMetadata = null;
  }

  /// Finishes the polygon drawing process.
  @override
  Future<void> finishDrawing({bool fromDelete = false}) async {
    try {
      if (_currentPolygon != null) {
        await _polygonAnnotationManager!.delete(_currentPolygon!);
      }
      if (_polygonPoints.length >= 3) {
        // Create the final polygon
        final newPoly = await _polygonAnnotationManager!.create(
          PolygonAnnotationOptions(
            geometry: Polygon.fromPoints(points: [_polygonPoints.toList()]),
            fillColor: (_currentDrawingFillColor)?.value,
            fillOutlineColor: (_currentDrawingOutlineColor)?.value,
            fillOpacity: _currentDrawingOpacity,
          ),
        );

        polygons.add(newPoly);

        // Store metadata in our Map if provided
        if (_currentDrawingMetadata != null) {
          _polygonMetadata[newPoly.id] = _currentDrawingMetadata!;
        }
        _emitPolygonsChange();
      }

      // Clear the drawing style after finishing
      clearDrawingStyle();

      // Clean up
      await _circleAnnotationManager!.deleteAll();
      _circleAnnotations.clear();
      _polygonPoints.clear();
      _emitPolygonPointsChange();
      _currentPolygon = null;

      if (onChange != null) {
        onChange!(GeometryChangeEvent(
          changeType: fromDelete == true
              ? GeometryChangeType.delete
              : GeometryChangeType.add,
          geometryType: GeometryType.polygon,
        ));
      }

      _controller.notifyListeners();
    } catch (e) {
      print('Error finalizing polygon: $e');
    }
  }

  /// Handles map tap events to add points to the polygon.
  Future<void> _onMapTapListener(MapContentGestureContext context) async {
    if (_controller.editingMode != EditingMode.DRAW_POLYGON ||
        _controller.isLoading) {
      return; // Only add points when in draw polygon mode and not loading
    }

    // Check if fully initialized before processing taps
    if (!_isInitialized) {
      print('PolygonHandler not fully initialized, ignoring tap.');
      return;
    }

    _controller._setLoading(true);
    _polygonPoints.add(context.point);
    _emitPolygonPointsChange();
    _controller.notifyListeners();

    try {
      if (_polygonPoints.length > 2) {
        // Create polygon if it doesn't exist
        if (_currentPolygon == null) {
          _currentPolygon = await _polygonAnnotationManager!.create(
            PolygonAnnotationOptions(
              geometry: Polygon.fromPoints(points: [_polygonPoints.toList()]),
              fillColor: _currentDrawingFillColor?.value,
              fillOutlineColor: _currentDrawingOutlineColor?.value,
              fillOpacity: _currentDrawingOpacity,
            ),
          );

          // Store metadata for preview polygon if provided
          if (_currentDrawingMetadata != null) {
            _polygonMetadata[_currentPolygon!.id] = _currentDrawingMetadata!;
          }
        }

        // Update the polygon with new points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [_polygonPoints.toList()]);

        await _polygonAnnotationManager!.update(_currentPolygon!);
      }

      // Create a visual marker (circle) at the tapped point
      final circleAnnotation = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: context.point,
          circleColor: _currentDrawingFillColor?.value,
        ),
      );

      // Store the circle annotation for future removal
      _circleAnnotations.add(circleAnnotation);
      _controller.notifyListeners();
    } catch (e) {
      print('Error adding polygon point: $e');
    } finally {
      _controller._setLoading(false);
    }
  }

  /// Deletes a polygon annotation.
  Future<void> deletePolygon(PolygonAnnotation polygon) async {
    try {
      if (_polygonAnnotationManager != null) {
        await _polygonAnnotationManager!.delete(polygon);
        polygons.removeWhere((poly) => poly.id == polygon.id);
        _polygonMetadata
            .remove(polygon.id); // Remove metadata for deleted polygon
        _emitPolygonsChange();

        if (onChange != null) {
          onChange!(GeometryChangeEvent(
            changeType: GeometryChangeType.delete,
            geometryType: GeometryType.polygon,
          ));
        }

        _controller.notifyListeners();
      }
    } catch (e) {
      print('Error deleting polygon: $e');
    }
  }

  /// Deletes all polygon annotations from the map.
  Future<void> deleteAllPolygons() async {
    try {
      if (_polygonAnnotationManager != null && polygons.isNotEmpty) {
        // Store count for the change event
        final deletedCount = polygons.length;

        // Delete all polygons from the map
        await _polygonAnnotationManager!.deleteAll();

        // Clear the polygons list
        polygons.clear();
        _polygonMetadata.clear(); // Clear all metadata
        _emitPolygonsChange();

        // Notify about the changes
        if (onChange != null) {
          for (int i = 0; i < deletedCount; i++) {
            onChange!(GeometryChangeEvent(
              changeType: GeometryChangeType.delete,
              geometryType: GeometryType.polygon,
            ));
          }
        }

        _controller.notifyListeners();
      }
    } catch (e) {
      print('Error deleting all polygons: $e');
    }
  }

  /// Undoes the last added point and removes the corresponding circle.
  @override
  Future<void> undoLastAction() async {
    if (_polygonPoints.isEmpty || _controller.isLoading) return;

    _controller._setLoading(true);
    _polygonPoints.removeLast();
    _emitPolygonPointsChange();
    _controller.notifyListeners();

    try {
      // Remove the last circle annotation
      if (_circleAnnotations.isNotEmpty) {
        final lastCircle = _circleAnnotations.removeLast();
        await _circleAnnotationManager!.delete(lastCircle);
      }

      if (_polygonPoints.length > 2) {
        // Update the polygon with the remaining points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [_polygonPoints.toList()]);

        await _polygonAnnotationManager!.update(_currentPolygon!);
      } else {
        // If less than 3 points, remove the polygon completely
        if (_currentPolygon != null) {
          await _polygonAnnotationManager!.delete(_currentPolygon!);
          _currentPolygon = null;
        }
      }

      _controller.notifyListeners();
    } catch (e) {
      print('Error undoing last polygon point: $e');
    } finally {
      _controller._setLoading(false);
    }
  }

  /// Dispose method to clean up annotation managers.
  @override
  void dispose() {
    super.dispose();
    _isInitialized = false;
    MapTapHandler().removeTapListener(_onMapTapListener);
    _polygonAnnotationManager?.deleteAll();
    _circleAnnotationManager?.deleteAll();
    _polygonPointsController.close();
    _polygonsController.close();
    polygons.clear();
  }
}

/// Internal class to handle polygon annotation clicks.
class _AnnotationClickListener extends OnPolygonAnnotationClickListener {
  final PolygonHandler _polygonHandler;

  _AnnotationClickListener(this._polygonHandler);

  @override
  void onPolygonAnnotationClick(PolygonAnnotation annotation) {
    if (_polygonHandler._controller.editingMode == EditingMode.DELETE) {
      _polygonHandler.deletePolygon(annotation);
    }
  }
}
