import "dart:convert";
import "dart:typed_data";

import "package:googleapis/datastore/v1.dart" as ds;

import "errors.dart";
import "entity.dart";
import "geo.dart";
import "key.dart";

class IndexedOverride<T> {
  IndexedOverride(this.value, {this.indexed});

  @override
  String toString() => "IndexedOverride($value, indexed: $indexed)";

  T value;
  bool indexed;
}

/// Converts an arbitrary object to an API value.
///
/// Apart from the basic types (`String`, `int`, `double`,
/// `bool`, and the `null` value) `ByteBuffer`, `TypedData`,
/// `Key` (including native API `Key`) and (possibly
/// heterogeneous) lists of these kinds are supported.
ds.Value toValue(Object obj, {bool excludeFromIndexes}) {
  if (obj is IndexedOverride) {
    bool exclude;
    if (obj.indexed != null) exclude = !obj.indexed;
    return toValue(obj.value, excludeFromIndexes: exclude);
  }
  if (obj is ds.Value) return obj;
  ds.Value result = new ds.Value();
  result.excludeFromIndexes = excludeFromIndexes;
  if (obj == null) return result..nullValue = "NULL_VALUE";
  if (obj is int) return result..integerValue = obj.toString();
  if (obj is double) return result..doubleValue = obj;
  if (obj is bool) return result..booleanValue = obj;
  if (obj is String) return result..stringValue = obj;
  if (obj is DateTime) return result..timestampValue = obj.toIso8601String();
  if (obj is Entity) return result..entityValue = obj.toApiObject();
  if (obj is ds.Entity) return result..entityValue = obj;
  if (obj is GeoPoint) return result..geoPointValue = obj.toApiObject();
  if (obj is ds.LatLng) return result..geoPointValue = obj;
  if (obj is TypedData || obj is ByteBuffer) {
    Uint8List bytes;
    if (obj is ByteBuffer) {
      bytes = obj.asUint8List();
    } else if (obj is Uint8List) {
      bytes = obj;
    } else {
      final TypedData typed = obj as TypedData;
      bytes =
          typed.buffer.asUint8List(typed.offsetInBytes, typed.lengthInBytes);
    }
    return result..blobValue = base64.encode(bytes);
  }
  if (obj is List) {
    result.excludeFromIndexes = null;
    List<ds.Value> values = obj
        .map((e) => toValue(e, excludeFromIndexes: excludeFromIndexes))
        .toList(growable: false);
    return result..arrayValue = (new ds.ArrayValue()..values = values);
  }
  if (obj is Key) return result..keyValue = obj.toApiObject();
  if (obj is ds.Key) return result..keyValue = obj;

  throw new DatastoreShellError("Not a value type: ${obj.runtimeType}(${obj})");
}

/// Converts an API value to a Dart object.
///
/// `null`, `String`, `int`, `double`, `bool` are returned as primitive
/// objects, `Key` values are mapped to entify `Key` objects, blobs are
/// mapped to `Uint8List` objects, and arrays are mapped to growable
/// `List` objects with their elements mapped recursively.
Object fromValue(ds.Value value) {
  if (value.nullValue == "NULL_VALUE") return null;
  if (value.integerValue != null) return int.parse(value.integerValue);
  if (value.doubleValue != null) return value.doubleValue;
  if (value.booleanValue != null) return value.booleanValue;
  if (value.stringValue != null) return value.stringValue;
  if (value.blobValue != null)
    return new Uint8List.fromList(value.blobValueAsBytes);
  if (value.arrayValue != null)
    return value.arrayValue.values?.map(fromValue)?.toList();
  if (value.keyValue != null) return new Key.fromApiObject(value.keyValue);
  if (value.timestampValue != null) return DateTime.parse(value.timestampValue);
  if (value.entityValue != null) return Entity.fromApiObject(value.entityValue);
  if (value.geoPointValue != null) return GeoPoint.fromApiObject(value.geoPointValue);

  // Nulls are represented in surprising ways
  Map json = value.toJson();
  json.remove("excludeFromIndexes");
  json.remove("meaning");
  if (json.isEmpty) return null;

  throw new DatastoreShellError("Unknown value type: ${value.toJson()}");
}
