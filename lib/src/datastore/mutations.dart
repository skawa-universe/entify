import "dart:async";
import "package:googleapis/datastore/v1.dart" as ds;

import "shell.dart";
import "entity.dart";
import "key.dart";

/// Represents a set of mutations that can be submitted with a commit call
/// (either transactionally or nontransactionally).
class MutationBatch {
  MutationBatch(this.shell);

  /// Adds an `insert` mutation to this batch.
  ///
  /// The given entity will be added to the datastore if an entity with the
  /// key does not exist yet or the entity has an incomplete key (in which
  /// case a unique id is generated).
  void insert(Entity e) => mutations.add(
        new ds.Mutation()..insert = e.toApiObject(),
      );

  /// Adds an `update` mutation to this batch.
  ///
  /// The given entity will overwritten in the datastore, an entity with the
  /// key must exist for this mutation to succeed. The key of the entity must
  /// be complete.
  void update(Entity e) => mutations.add(
        new ds.Mutation()..update = e.toApiObject(),
      );

  /// Adds an `upsert` mutation to this batch.
  ///
  /// The given entity will inserted or overwritten in the datastore. If the key
  /// is complete this is done regardless of whether an entity with the same key
  /// exists. The key can also be incomplete in which case a unique id will be
  /// generated and an insertion will be performed.
  void upsert(Entity e) => mutations.add(
        new ds.Mutation()..upsert = e.toApiObject(),
      );

  /// Adds a `delete` mutation to this batch.
  ///
  /// Deletes the entity with the key. The key must be complete. The entity with
  /// the key may or may not exist.
  void delete(Key key) => mutations.add(
        new ds.Mutation()..delete = key.toApiObject(),
      );

  /// Adds multiple `insert` mutations to this batch.
  ///
  /// The given entity will be added to the datastore if an entity with the
  /// key does not exist yet or the entity has an incomplete key (in which
  /// case a unique id is generated).
  void insertAll(Iterable<Entity> entities) => mutations.addAll(
        entities.map((e) => new ds.Mutation()..insert = e.toApiObject()),
      );

  /// Adds multiple `update` mutations to this batch.
  ///
  /// The given entity will overwritten in the datastore, an entity with the
  /// key must exist for this mutation to succeed. The key of the entity must
  /// be complete.
  void updateAll(Iterable<Entity> entities) => mutations.addAll(
        entities.map((e) => new ds.Mutation()..update = e.toApiObject()),
      );

  /// Adds multiple `upsert` mutations to this batch.
  ///
  /// The given entity will inserted or overwritten in the datastore. If the key
  /// is complete this is done regardless of whether an entity with the same key
  /// exists. The key can also be incomplete in which case a unique id will be
  /// generated and an insertion will be performed.
  void upsertAll(Iterable<Entity> entities) => mutations.addAll(
        entities.map((e) => new ds.Mutation()..upsert = e.toApiObject()),
      );

  /// Adds multiple `delete` mutations to this batch.
  ///
  /// Deletes the entity with the key. The key must be complete. The entity with
  /// the key may or may not exist.
  void deleteAll(Iterable<Key> keys) => mutations.addAll(
        keys.map((key) => new ds.Mutation()..delete = key.toApiObject()),
      );

  /// Executes all the mutations.
  Future<MutationBatchResponse> execute() => executeRaw().then(
        (ds.CommitResponse resp) => new MutationBatchResponse(shell, resp));

  /// Creates a `package:googleapis` request object for this batch.
  ///
  /// Normally you would need [execute], this is for tinkering with the request
  /// before sending it out.
  ds.CommitRequest createRequest() => new ds.CommitRequest()
    ..mutations = mutations
    ..mode = "NON_TRANSACTIONAL";

  /// Executes all the mutations and returns asynchronically with the raw `package:googleapis`
  /// response object.
  Future<ds.CommitResponse> executeRaw() {
        DatastoreShell shell = this.shell;
    ds.CommitRequest req = createRequest();
    return shell.api.projects.commit(req, shell.project);
  }

  /// Provides an access to all the mutations the object has generated for tinkering.
  List<ds.Mutation> mutations = [];

  /// The [DatastoreShell] object this mutation batch object belongs to.
  final DatastoreShell shell;
}

/// The result of a mutation is an array of keys which are set to either the generated keys
/// or to `null` if no key generation was necessary.
class MutationBatchResponse {
  MutationBatchResponse(this.shell, ds.CommitResponse response)
      : _size = response.mutationResults.length {
    int index = -1;
    response.mutationResults.forEach((ds.MutationResult result) {
      ++index;
      if (result.key != null) {
        if (_keys == null) _keys = new List.filled(_size, null);
        _keys[index] = new Key.fromProtocol(result.key);
      }
    });
  }

  /// Returns the keys that have been generated.
  ///
  /// Every element corresponds to a mutation in the batch and is set to
  /// the key that was generated or `null` if no key generation was necessary
  /// for the corresponding mutation.
  List<Key> get keys {
    if (_keys == null) _keys = new List.filled(_size, null);
    return _keys;
  }

  List<Key> _keys;

  final int _size;

  /// The associated [DatastoreShell] object.
  final DatastoreShell shell;
}
