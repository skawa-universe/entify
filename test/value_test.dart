import "dart:typed_data";
import "dart:convert" as dc;

import "package:googleapis/datastore/v1.dart" as ds;
import "package:entify/entify.dart";
import "package:test/test.dart";

class Identity {
  const Identity(this.name);

  final String name;
}

const Object same = const Identity("same");
const Object inputToString = const Identity("inputToString");

Object base64(Object buffer) {
  if (buffer is TypedData) buffer = (buffer as TypedData).buffer;
  return dc.base64
      .encode((buffer as ByteBuffer).asUint8List())
      .replaceAll("/", "_")
      .replaceAll("+", "-");
}

ds.Value jsonValue(Map<dynamic, dynamic> json) => new ds.Value.fromJson(json);

void testToValueWith(String fieldName, dynamic inputValue,
    [dynamic outputValue = inputToString]) {
  if (outputValue is Function) outputValue = outputValue(inputValue);
  if (identical(outputValue, same)) outputValue = inputValue;
  if (identical(outputValue, inputToString))
    outputValue = inputValue.toString();
  expect(toValue(inputValue).toJson(), equals({fieldName: outputValue}));
  expect(toValue(inputValue, excludeFromIndexes: true).toJson(),
      equals({fieldName: outputValue, "excludeFromIndexes": true}));
  expect(toValue(inputValue, excludeFromIndexes: false).toJson(),
      equals({fieldName: outputValue, "excludeFromIndexes": false}));
}

void testFromValueWith(String fieldName, dynamic inputValue,
    [dynamic outputValue = inputToString]) {
  if (outputValue is Function) outputValue = outputValue(inputValue);
  if (identical(outputValue, same)) outputValue = inputValue;
  if (identical(outputValue, inputToString))
    outputValue = inputValue.toString();
  expect(fromValue(jsonValue({fieldName: outputValue})), equals(inputValue));
  expect(
      fromValue(
          jsonValue({fieldName: outputValue, "excludeFromIndexes": true})),
      equals(inputValue));
  expect(
      fromValue(
          jsonValue({fieldName: outputValue, "excludeFromIndexes": false})),
      equals(inputValue));
}

void testListToValue(List<dynamic> input, {bool excludeFromIndexes}) {
  Map<dynamic, dynamic> json =
      toValue(input, excludeFromIndexes: excludeFromIndexes).toJson();
  List<Map<dynamic, dynamic>> expectedList = input
      .map((e) => toValue(e, excludeFromIndexes: excludeFromIndexes).toJson())
      .toList();
  Map<dynamic, dynamic> expected = {
    "arrayValue": {"values": expectedList}
  };
  expect(json, equals(expected));
}

void testListFromValue(List<dynamic> input, {bool excludeFromIndexes}) {
  List<Map<dynamic, dynamic>> inputList = input
      .map((e) => toValue(e, excludeFromIndexes: excludeFromIndexes).toJson())
      .toList();
  Map<dynamic, dynamic> inputJson = {
    "arrayValue": {"values": inputList}
  };
  expect(fromValue(jsonValue(inputJson)), equals(input));
}

void main() {
  test("toValue(int)", () => testToValueWith("integerValue", -1234));
  test("toValue(double)", () => testToValueWith("doubleValue", -12.34, same));
  test("toValue(bool)", () => testToValueWith("booleanValue", true, same));
  test("toValue(nullValue)",
      () => testToValueWith("nullValue", null, "NULL_VALUE"));
  test("toValue(String)", () => testToValueWith("stringValue", "foo", same));

  Key key = new Key("Foo", id: 5, parent: new Key("Bar", name: "abcd_efgh"));
  test("toValue(Key)",
      () => testToValueWith("keyValue", key, key.toApiObject().toJson()));

  test("toValue(List)", () {
    for (bool exclude in [null, true, false]) {
      testListToValue([1, "two", 3.3], excludeFromIndexes: exclude);
    }
  });

  Uint16List shortList =
      new Uint16List.fromList([2000, 4000, 8000, 16000, 32000]);
  Uint8List shortListAsBytes = shortList.buffer.asUint8List();
  test(
    "toValue(buffer)",
    () => testToValueWith("blobValue", shortList, base64),
  );

  test("fromValue(int)", () => testFromValueWith("integerValue", -1234));
  test("fromValue(double)",
      () => testFromValueWith("doubleValue", -12.34, same));
  test("fromValue(bool)", () => testFromValueWith("booleanValue", true, same));
  test("fromValue(nullValue)",
      () => testFromValueWith("nullValue", null, "NULL_VALUE"));
  test(
      "fromValue(String)", () => testFromValueWith("stringValue", "foo", same));
  test("fromValue(Key)",
      () => testFromValueWith("keyValue", key, key.toApiObject().toJson()));

  test("fromValue(List)", () {
    for (bool exclude in [null, true, false]) {
      testListFromValue([1, "two", 3.3], excludeFromIndexes: exclude);
    }
  });

  test("fromValue(mixed indexed list)", () {
    List<Object> sample = [1, "two", 3.3];
    List<bool> excludes = [null, true, false];
    expect(sample.length, excludes.length, reason: "test case sanity check");
    List<IndexedOverride<Object>> overridden = [];
    for (int i = 0; i < sample.length; ++i) {
      bool excluded = excludes[i % excludes.length];
      bool indexed;
      if (excluded != null) indexed = !excluded;
      overridden.add(new IndexedOverride(sample[i], indexed: indexed));
    }
    for (bool exclude in [null, true, false]) {
      ds.Value value = toValue(overridden, excludeFromIndexes: exclude);
      expect(value.excludeFromIndexes, isNull);
      expect(value.arrayValue, isNotNull);
      List<ds.Value> values = value.arrayValue.values;
      expect(values.length, 3);
      for (int i = 0; i < excludes.length; ++i) {
        expect(values[i].excludeFromIndexes, excludes[i]);
        expect(values[i].toJson(),
            toValue(sample[i], excludeFromIndexes: excludes[i]).toJson());
      }
    }
  });

  test(
    "fromValue(buffer)",
    () => testToValueWith("blobValue", shortListAsBytes, base64),
  );
}
