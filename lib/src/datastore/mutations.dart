import "dart:async";
import "package:googleapis/datastore/v1.dart" as ds;

import "shell.dart";
import "entity.dart";
import "errors.dart";
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
  MutationBatch insert(Entity e) {
    mutations.add(new ds.Mutation()..insert = e.toApiObject());
    return this;
  }

  /// Adds an `update` mutation to this batch.
  ///
  /// The given entity will overwritten in the datastore, an entity with the
  /// key must exist for this mutation to succeed. The key of the entity must
  /// be complete.
  MutationBatch update(Entity e) {
    mutations.add(new ds.Mutation()..update = e.toApiObject());
    return this;
  }

  /// Adds an `upsert` mutation to this batch.
  ///
  /// The given entity will inserted or overwritten in the datastore. If the key
  /// is complete this is done regardless of whether an entity with the same key
  /// exists. The key can also be incomplete in which case a unique id will be
  /// generated and an insertion will be performed.
  MutationBatch upsert(Entity e) {
    mutations.add(new ds.Mutation()..upsert = e.toApiObject());
    return this;
  }

  /// Adds a `delete` mutation to this batch.
  ///
  /// Deletes the entity with the key. The key must be complete. The entity with
  /// the key may or may not exist.
  MutationBatch delete(Key key) {
    mutations.add(new ds.Mutation()..delete = key.toApiObject());
    return this;
  }

  /// Adds multiple `insert` mutations to this batch.
  ///
  /// The given entity will be added to the datastore if an entity with the
  /// key does not exist yet or the entity has an incomplete key (in which
  /// case a unique id is generated).
  MutationBatch insertAll(Iterable<Entity> entities) {
    mutations.addAll(entities.map((e) => new ds.Mutation()..insert = e.toApiObject()));
    return this;
  }

  /// Adds multiple `update` mutations to this batch.
  ///
  /// The given entity will overwritten in the datastore, an entity with the
  /// key must exist for this mutation to succeed. The key of the entity must
  /// be complete.
  MutationBatch updateAll(Iterable<Entity> entities) {
    mutations.addAll(entities.map((e) => new ds.Mutation()..update = e.toApiObject()));
    return this;
  }

  /// Adds multiple `upsert` mutations to this batch.
  ///
  /// The given entity will inserted or overwritten in the datastore. If the key
  /// is complete this is done regardless of whether an entity with the same key
  /// exists. The key can also be incomplete in which case a unique id will be
  /// generated and an insertion will be performed.
  MutationBatch upsertAll(Iterable<Entity> entities) {
    mutations.addAll(entities.map((e) => new ds.Mutation()..upsert = e.toApiObject()));
    return this;
  }

  /// Adds multiple `delete` mutations to this batch.
  ///
  /// Deletes the entity with the key. The key must be complete. The entity with
  /// the key may or may not exist.
  MutationBatch deleteAll(Iterable<Key> keys) {
    mutations.addAll(keys.map((key) => new ds.Mutation()..delete = key.toApiObject()));
    return this;
  }

  /// Commits all the mutations.
  ///
  /// Throws [ConcurrentModificationError] if the transaction has failed (unless it is
  /// transactional this may mean that some mutations have succeeded).
  Future<MutationBatchResponse> commit() =>
      commitRaw().then((ds.CommitResponse resp) => new MutationBatchResponse(shell, resp), onError: (error) {
        if (error is ds.DetailedApiRequestError) {
          if (error.status == 400 || error.status == 409) {
            throw new DatastoreConflictError(
                error.status == 400
                    ? "An insert/update mutation could not be completed"
                    : "The transaction ran into a conflict",
                error);
          } else if (error.status == 500) {
            throw new DatastoreTransientError(error.message ?? "A transient error has occured", error);
          } else {
            throw new UnknownDatastoreError(error.message, error);
          }
        }
        throw error;
      });

  @deprecated
  Future<MutationBatchResponse> execute() => commit();

  /// Creates a `package:googleapis` request object for this batch.
  ///
  /// Normally you would need [commit], this is for tinkering with the request
  /// before sending it out.
  ds.CommitRequest createRequest() => new ds.CommitRequest()
    ..mutations = mutations
    ..transaction = shell.transactionId
    ..mode = shell.isTransactional ? "TRANSACTIONAL" : "NON_TRANSACTIONAL";

  /// Commits all the mutations and returns asynchronically with the raw `package:googleapis`
  /// response object.
  Future<ds.CommitResponse> commitRaw() {
    DatastoreShell shell = this.shell;
    ds.CommitRequest req = createRequest();
    return shell.api.projects.commit(req, shell.project);
  }

  @deprecated
  Future<ds.CommitResponse> executeRaw() => commitRaw();

  /// Provides an access to all the mutations the object has generated for tinkering.
  List<ds.Mutation> mutations = [];

  /// The [DatastoreShell] object this mutation batch object belongs to.
  final DatastoreShell shell;
}

/// The result of a mutation is an array of keys which are set to either the generated keys
/// or to `null` if no key generation was necessary.
class MutationBatchResponse {
  MutationBatchResponse(this.shell, ds.CommitResponse response) : _size = response.mutationResults.length {
    int index = -1;
    _hasConflicts = false;
    response.mutationResults.forEach((ds.MutationResult result) {
      ++index;
      if (result.conflictDetected ?? false) {
        _hasConflicts = true;
        if (_conflictDetected == null) _conflictDetected = new List.filled(_size, null);
        _conflictDetected[index] = true;
      }
      if (result.key != null) {
        if (_keys == null) _keys = new List.filled(_size, null);
        _keys[index] = new Key.fromApiObject(result.key);
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

  List<bool> get conflictDetected {
    if (_conflictDetected == null) _conflictDetected = new List.filled(_size, false);
    return _conflictDetected;
  }

  bool get hasConflicts => _hasConflicts;

  List<Key> _keys;
  List<bool> _conflictDetected;
  bool _hasConflicts;

  final int _size;

  /// The associated [DatastoreShell] object.
  final DatastoreShell shell;
}
