## 0.4.0+2

* Added an example, fixed linter warnings

## 0.4.0+1

* Collection type adaptation fix

## 0.4.0

* Dart 2 support

## 0.3.0

* Entity kind is checked on deserialization (but can be disabled)
* `IndexedOverride` is checked and stripped in `Entity` (though not for iterable value items, that
  is taken care of during API value object conversion)
* Improved error handling
* Introduced value deep copy to `Entity.setPropertiesFrom`, which will duplicate iterables (as lists),
  the default behavior is to shallow copy values
* Added an `Entity.copy` constructor, which will by default create a deep copy of an entity, but this
  can be overridden
* The EntityBridge uses metadata from both the getter and setter (previously only the getter was taken
  into account)

## 0.2.4

* Added an option to the `EntityBridge` metadata classes skip setting properties that
  are missing in the entity.
* Introduced `version` in `Entity` that saves the `version` in the fetch and query
  results.
* EntityBridge can set version fields if they are available.
* `MutationBatch` can return the affected keys with `relatedKeys`.
* All `get` functions now handle deferred reads automatically.
* Introduced the `IndexOverride` wrapper which can override whether an entity model
  field value has to be indexed or not.

## 0.2.3

* Added `containsProperty` to `Entity`
* The `remove` method on `Entity` returns the previously set value.
* The read consistency can be specified with `get` calls
* The default read consistency has been changed to `null` which means the service side
  default, which is different what it used to be with `get` calls and ancestor queries.

## 0.2.2

* `Entity`: fixed `propertyNames` added `toString`
* `WrappedServerError` will tell about the wrapped error in `toString`
* Added a `null` check for the `kind` in the `Key` constructor
* Incomplete `Key` values in entities are checked (they can still fail mutations if they are in a list)
* Added `EntityBridge` methods that can be used as predicates: `entityKindMatches` and `keyKindMatches`

## 0.2.1+1

* Fixed blob value handling

## 0.2.1

* Added `indexedIfNonNull`.
* Entity now supports accessing property names, so properties are now enumerable.
* Empty commits are handled.
* The `setPropertiesFrom` in the `Entity` class allows future proof entity updates.

## 0.2.0

* Added support for transactions.
* Renamed `MutationBatch.execute` and `executeRaw` to `commit`.
  The `execute` methods are deprecated now and will be removed in a future release.

## 0.1.2+2

* Setters are optional for properties in entity model classes

## 0.1.2+1

* Handles `null` values in `fromValue` better
* Throws error if the entity model class does not have a key

## 0.1.2

* Renamed `fromProtocol` to `fromApiObject` in `Key` and `Entity` to follow
  common naming convention
* `fromValue` now handles empty values (treats them as `null`)
* `Entity` throws more meaningful errors in `fromApiObject`

## 0.1.1+3

* Added `createKey` method to `EntityBridge`
* Created `QueryResult` interface

## 0.1.1

* The `bool` parameter of `toValue` became a named parameter as it is recommended.
