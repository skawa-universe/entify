import "package:googleapis/datastore/v1.dart" as ds;
import "package:entify/entify.dart";
import "package:test/test.dart";

void main() {
  test("Index preservation", () {
    ds.Entity entity = ds.Entity();
    entity.key = ds.Key()..path = [ds.PathElement()..kind = "E"..name = "f"];
    ds.ArrayValue array = ds.ArrayValue()..values = [
      ds.Value()..stringValue = "foo"
    ];
    ds.ArrayValue unindexedArray = ds.ArrayValue()..values = [
      ds.Value()..stringValue = "foo"..excludeFromIndexes = true
    ];
    ds.ArrayValue indexedArray = ds.ArrayValue()..values = [
      ds.Value()..stringValue = "foo"..excludeFromIndexes = false
    ];
    entity.properties = {
      "implicitIndexed": ds.Value()..integerValue = "12345",
      "explicitIndexed": ds.Value()..integerValue = "12345"..excludeFromIndexes = false,
      "explicitUnindexed": ds.Value()..integerValue = "12345"..excludeFromIndexes = true,
      "array": ds.Value()..arrayValue = array,
      "indexedArray": ds.Value()..arrayValue = indexedArray,
      "unindexedArray": ds.Value()..arrayValue = unindexedArray,
    };
    Entity mapped = Entity.fromApiObject(entity);
    expect(mapped.isIndexed("implicitIndexed"), isTrue);
    expect(mapped.isIndexed("explicitIndexed"), isTrue);
    expect(mapped.isIndexed("explicitUnindexed"), isFalse);
    expect(mapped.isIndexed("array"), isTrue);
    expect(mapped.isIndexed("indexedArray"), isTrue);
    expect(mapped.isIndexed("unindexedArray"), isFalse);
  });
}
