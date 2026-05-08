// lib/src/models/geometry_styles.dart

part of '../mapbox_maps_flutter_draw.dart';

class GeometryStyle {
  final Color? color;
  final double? width;
  final Color? strokeColor;
  final double? strokeWidth;
  final double? opacity;

  GeometryStyle({
    this.color,
    this.width,
    this.strokeColor,
    this.strokeWidth,
    this.opacity,
  });
}

class GeometryStyles {
  final GeometryStyle? pointStyle;
  final GeometryStyle? lineStyle;
  final GeometryStyle? polygonStyle;

  GeometryStyles({
    this.pointStyle,
    this.lineStyle,
    this.polygonStyle,
  });

  // Default styles can be defined here
  factory GeometryStyles.defaultStyles() {
    return GeometryStyles(
      pointStyle: GeometryStyle(
          color: Colors.blue,
          width: 6.0,
          strokeColor: Colors.white,
          strokeWidth: 2.0,
          opacity: 0.8),
      lineStyle: GeometryStyle(
          color: Colors.green,
          width: 6.0,
          strokeColor: Colors.white,
          strokeWidth: 2.0,
          opacity: 0.8),
      polygonStyle: GeometryStyle(
          color: Colors.red,
          width: 6.0,
          strokeColor: Colors.white,
          strokeWidth: 2,
          opacity: 0.8),
    );
  }
}

/// A class that pairs a polygon geometry with optional individual styling.
/// Use this when you want to add multiple polygons with different colors.
class PolygonData {
  /// The polygon geometry
  final Polygon polygon;

  /// The fill color for this polygon. If null, uses the default style color.
  final Color? fillColor;

  /// The outline color for this polygon. If null, uses the default style stroke color.
  final Color? outlineColor;

  /// The outline thickness in pixels. If null, uses the default style stroke width.
  /// Mapbox's native fill-outline is fixed at 1px, so the package renders the
  /// outline as a separate line annotation to honour this value.
  final double? outlineWidth;

  /// The opacity for this polygon. If null, uses the default style opacity.
  final double? opacity;

  /// Optional metadata to associate with this polygon.
  /// This can be any JSON-serializable map that you want to store with the polygon.
  final Map<String, dynamic>? metadata;

  PolygonData({
    required this.polygon,
    this.fillColor,
    this.outlineColor,
    this.outlineWidth,
    this.opacity,
    this.metadata,
  });

  /// Creates a PolygonData from just a Polygon geometry with default styling.
  factory PolygonData.fromPolygon(Polygon polygon) {
    return PolygonData(polygon: polygon);
  }
}
