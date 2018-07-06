# entify

A library to ease the use of the datastore with the `googleapis` package.

## Features

Entity model mapping:

```dart
// ...

@entityModel
class Species {
  // This will handle the mapping between entify's Entity object and this model
  static final EntityBridge<Species> bridge = new EntityBridge<Species>();

  Species();

  // You can use a factory constructor for setting up an object from an entity.
  // This isn't really needed, I just like to create these shorthand constructors,
  // the bridge.fromEntity can be called anywhere.
  factory Species.fromEntity(Entity e) => bridge.fromEntity(e, new Species());

  // Or you can use a vanilla constructor if you prefer.
  Species.entity(Entity e) {
    bridge.fromEntity(e, this);
  }

  // Shorthand function for mapping this to an entify Entity object.
  Entity toEntity() => bridge.toEntity(this);

  @primaryKey
  String scientificName;
  @persistent
  String commonName;
  @persistent
  String status;

  // Fields can be renamed, marked as unindexed (not demonstrated here).
  @Persistent(name: "taxonomy")
  List<String> get taxonomyField => taxonomy.map((e) => e.toString()).toList();

  set taxonomyField(List<String> encodedTaxonomy) { /* ... */ }

  // This field is converted to/from a property via a getter/setter respectively.
  List<Taxon> taxonomy = [];

  // This is a lookup field generated from taxonomy, it doesn't need a setter.
  @persistent
  List<String> get taxonomyPaths { /* ... */ }

  // This is a non-persistent property.
  String get fullTaxonomyPath => taxonomy.join('/');
}
```

You can save some objects just by calling:
```dart
Future<Null> insertOrUpdateSpecies(DatastoreShell dsh, Iterable<Species> species) async {
  await (dsh.beginMutation()
      ..upsertAll(species.map((s) => s.toEntity())))
    .commit();
}
```

All the elements are optional, you can create `googleapis` level API objects and
modify them if something is not supported.

## Getting Started

Check out the https://github.com/skawa-universe/endangered_species/ project
for an example and details on the class provided above.
