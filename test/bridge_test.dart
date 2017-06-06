import "dart:typed_data";

import "package:entify/entify.dart";
import "package:test/test.dart";

class Box<T> {
  Box(this.value);

  int get hashCode => value.hashCode;

  bool operator ==(dynamic other) => other is Box && other.value == value;

  final T value;
}

@EntityModel(kind: "TestKind")
class TestClass {
  @primaryKey
  int key;

  @persistent
  String name;

  @Persistent(name: "renamed", indexed: false)
  String address;

  @unindexed
  String get unbox => box.value;

  void set unbox(String value) {
    box = new Box(value);
  }

  Box<String> box;

  @unindexed
  Uint8List bytes;
}

main() {
  test("Basic serialization", () {
    const List<int> bytesAsList = const <int>[0, 50, 100, 150, 200, 250];

    EntityBridge<TestClass> tcb = new EntityBridge.fromClass(TestClass);
    TestClass tc = new TestClass();
    tc.key = 12345;
    tc.name = "foo";
    tc.address = "Nowhere";
    tc.box = new Box("bar");
    tc.bytes = new Uint8List.fromList(bytesAsList);

    Entity e = tcb.toEntity(tc);
    expect(e.key.kind, equals("TestKind"), reason: "Key kind is correct");
    expect(e.key.id, equals(12345), reason: "Key id is correct");
    expect(e.key.name, isNull, reason: "Key name is unspecified");
    expect(e.indexed["name"], "foo", reason: "Indexed property exists and indexed");
    expect(e.unindexed["renamed"], "Nowhere");
    expect(e.unindexed["unbox"], "bar");
    expect(e.unindexed["bytes"], equals(bytesAsList));
  });

  test("Basic deserialization", () {
    const List<int> bytesAsList = const <int>[255, 127, 63, 31, 15, 7];

    EntityBridge<TestClass> tcb = new EntityBridge.fromClass(TestClass);
    Entity e = new Entity();
    e.key = new Key("TestKind", id: 456);
    e.indexed["name"] = "Henry Fanshaw";
    e.unindexed["renamed"] = "Somewhere";
    e.unindexed["unbox"] = "pub";
    e.unindexed["bytes"] = new Uint8List.fromList(bytesAsList);
    TestClass tc = new TestClass();
    tcb.fromEntity(e, tc);

    expect(tc.key, equals(456), reason: "Key id is correct");
    expect(tc.name, "Henry Fanshaw", reason: "Indexed property exists and indexed");
    expect(tc.address, "Somewhere");
    expect(tc.box, new Box("pub"));
    expect(tc.bytes, equals(bytesAsList));
  });

  test("EntityBridge instantiation from generic parameter", () {
    expect(() {
      new EntityBridge();
    }, throwsArgumentError);

    expect((){
      new EntityBridge<TestClass>();
    }, isNot(throwsA(anything)));
  });
}
