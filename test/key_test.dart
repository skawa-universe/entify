import "package:googleapis/datastore/v1.dart" as ds;
import "package:entify/entify.dart";
import "package:test/test.dart";

void main() {
  test("Basic usage", () {
    Key key = new Key("Foo", name: "bar", parent: new Key("Numeric", id: 7));
    ds.Key apiKey = key.toApiObject();
    expect(apiKey.partitionId, isNull);
    expect(apiKey.path.length, 2);
    expect(apiKey.path[0].kind, "Numeric");
    expect(apiKey.path[0].name, isNull);
    expect(apiKey.path[0].id, "7");
    expect(apiKey.path[1].kind, "Foo");
    expect(apiKey.path[1].name, "bar");
    expect(apiKey.path[1].id, isNull);
  });
  test("Namespace handling", () {
    Key key = withNamespace("ns",
        () => new Key("Foo", name: "bar", parent: new Key("Numeric", id: 7)));
    ds.Key apiKey = key.toApiObject();
    expect(apiKey.partitionId, isNotNull);
    expect(apiKey.partitionId.namespaceId, "ns");
    expect(apiKey.partitionId.projectId, isNull);
    expect(apiKey.path.length, 2);
    expect(apiKey.path[0].kind, "Numeric");
    expect(apiKey.path[0].name, isNull);
    expect(apiKey.path[0].id, "7");
    expect(apiKey.path[1].kind, "Foo");
    expect(apiKey.path[1].name, "bar");
    expect(apiKey.path[1].id, isNull);
  });
}
