import "dart:typed_data";

import "package:entify/entify.dart";
import "package:test/test.dart";

class Box<T> {
  Box(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
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

  set unbox(String value) {
    box = new Box(value);
  }

  Box<String> box;

  @unindexed
  Uint8List bytes;

  @persistent
  String get generatedField => name.toUpperCase();
}

@EntityModel(skipMissingProperties: true)
class SkipMissing {
  @primaryKey
  int key;

  @persistent
  int alpha;

  @persistent
  String beta = "foo";

  @Persistent(skipIfMissing: false)
  bool gamma = false;
}

@entityModel
class NoSkipMissing {
  @primaryKey
  int key;

  @persistent
  int alpha;

  @persistent
  String beta = "foo";

  @Persistent(skipIfMissing: true)
  bool gamma = false;
}

class LowerCaseValue extends ValueHolder<String> {
  @override
  String get value => _value?.toLowerCase();

  @override
  set value(String newValue) => _value = newValue;

  String _value;
}

class EvenInt extends ValueHolder<int> {
  @override
  int get value => _value == null ? null : _value & ~1;

  @override
  set value(int newValue) => _value = newValue;

  int _value;
}

@entityModel
class ModelWithLowerCaseValue {
  @primaryKey
  final EvenInt key = EvenInt();

  @persistent
  final LowerCaseValue s = LowerCaseValue();
}

void main() {
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
    expect(e.indexed["name"], "foo",
        reason: "Indexed property exists and indexed");
    expect(e.unindexed["renamed"], "Nowhere");
    expect(e.unindexed["unbox"], "bar");
    expect(e.unindexed["bytes"], equals(bytesAsList));
    expect(e.indexed["generatedField"], equals("FOO"));
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
    e.indexed["generatedField"] = "RNZAF";
    TestClass tc = new TestClass();
    tcb.fromEntity(e, tc);

    expect(tc.key, equals(456), reason: "Key id is correct");
    expect(tc.name, "Henry Fanshaw",
        reason: "Indexed property exists and indexed");
    expect(tc.address, "Somewhere");
    expect(tc.box, new Box("pub"));
    expect(tc.bytes, equals(bytesAsList));
  });

  test("EntityBridge instantiation from generic parameter", () {
    expect(() {
      new EntityBridge();
    }, throwsArgumentError);

    expect(() {
      new EntityBridge<TestClass>();
    }, isNot(throwsA(anything)));
  });

  test("EntityBridge skips missing properties", () {
    NoSkipMissing nsm = new NoSkipMissing();
    nsm.key = 3;
    SkipMissing sm = new SkipMissing();
    sm.key = 3;
    Entity e = new Entity();
    e.indexed["alpha"] = 7;
    EntityBridge<SkipMissing> bridge = new EntityBridge<SkipMissing>();
    EntityBridge<NoSkipMissing> nonSkippingBridge =
        new EntityBridge<NoSkipMissing>();
    bridge.fromEntity(e, sm);
    nonSkippingBridge.fromEntity(e, nsm);
    expect(sm.key, 3);
    expect(sm.alpha, 7);
    expect(sm.beta, "foo");
    expect(sm.gamma, isNull);

    expect(nsm.key, 3);
    expect(nsm.alpha, 7);
    expect(nsm.beta, isNull);
    expect(nsm.gamma, false);
  });

  test("ValueHolder", () {
    ModelWithLowerCaseValue model = ModelWithLowerCaseValue();
    EntityBridge<ModelWithLowerCaseValue> bridge = EntityBridge(modelFactory: () => ModelWithLowerCaseValue());
    model.s.value = "Foo";
    model.key.value = 11;
    Entity e = bridge.toEntity(model);
    expect(e.key.id, 10);
    expect(e.isIndexed("s"), isTrue);
    expect(e["s"], "foo");
    e.key = bridge.createKey(id: 15);
    e.setValue("s", "Bar", indexed: true);
    model = bridge.fromEntity(e);
    expect(model.s.value, "bar");
    expect(model.key.value, 14);
  });
}
