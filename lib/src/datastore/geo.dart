import "package:googleapis/datastore/v1.dart" as ds;

import "api_mapping.dart";
import "util.dart";

/// An object representing a latitude/longitude pair. This is expressed as a
/// pair of doubles representing degrees latitude and degrees longitude. Unless
/// specified otherwise, this must conform to the WGS84 standard. Values must be
/// within normalized ranges.
class GeoPoint implements ApiRepresentation<ds.LatLng> {
  /// Construct an immutable GeoPoint.
  /// The latitude and longitude are in degrees.
  /// The latitude must be in the range [-90.0, +90.0].
  /// The longitude must be in the range [-180.0, +180.0].
  const GeoPoint(this.latitude, this.longitude);

  /// Creates a GeoPoint from the `package:googleapis` representation.
  factory GeoPoint.fromApiObject(ds.LatLng obj) =>
      GeoPoint(obj.latitude, obj.longitude);

  /// Converts the GeoPoint to the `package:googleapis` representation.
  @override
  ds.LatLng toApiObject() => ds.LatLng()
    ..latitude = latitude
    ..longitude = longitude;

  @override
  String toString() => "($latitude, $longitude)";

  @override
  int get hashCode => combineHash(latitude.hashCode, longitude.hashCode);

  @override
  bool operator ==(dynamic other) =>
      other is GeoPoint &&
      latitude == other.latitude &&
      longitude == other.longitude;

  /// The latitude in degrees. It must be in the range [-90.0, +90.0].
  final double latitude;

  /// The longitude in degrees. It must be in the range [-180.0, +180.0].
  final double longitude;
}
