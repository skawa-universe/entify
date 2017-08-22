import "package:googleapis/datastore/v1.dart" as ds;

import "errors.dart";
import "values.dart";
import "api_mapping.dart";

/// Every class that can be used as a filter implements this interface.
abstract class Filter extends ApiRepresentation<ds.Filter> {
  static Filter and(List<FilterPredicate> predicates) {
    if (predicates == null || predicates.isEmpty) return null;
    if (predicates.length == 1) return predicates[0];
    return new CompoundFilter.and(predicates);
  }
}

/// Every class that can be used as a filter predicate implements this interface.
abstract class FilterPredicate extends Filter {}

/// A compound filter has a list of filter predicates.
///
/// Currently only the `and` operator is supported.
class CompoundFilter implements Filter {
  CompoundFilter.and(this.predicates);
  CompoundFilter.fromProtocol(ds.Filter filter)
      : predicates = filter.compositeFilter.filters
            .map((f) => new PropertyFilterPredicate.fromProtocol(f))
            .toList() {
    if (filter.compositeFilter.op != "AND") {
      throw new DatastoreShellError(
          "Only \"AND\" operator is supported in compound filters");
    }
  }

  @override
  ds.Filter toApiObject() => new ds.Filter()
    ..compositeFilter = (new ds.CompositeFilter()
      ..filters =
          predicates.map(ApiRepresentation.mapToApi).toList(growable: false)
      ..op = "AND");
  final Iterable<FilterPredicate> predicates;
}

/// Filters on a single property.
class PropertyFilterPredicate implements FilterPredicate {
  /// Creates a filter on property [name] that must match [value] with
  /// operator [op].
  const PropertyFilterPredicate(this.name, this.op, this.value);

  PropertyFilterPredicate.fromProtocol(ds.Filter filter)
      : name = filter.propertyFilter.property.name,
        op = FilterOperator.lookup(filter.propertyFilter.op),
        value = fromValue(filter.propertyFilter.value);

  @override
  ds.Filter toApiObject() => new ds.Filter()
    ..propertyFilter = (new ds.PropertyFilter()
      ..property = (new ds.PropertyReference()..name = name)
      ..op = op.opName
      ..value = toValue(value));

  /// The name of the property that must match.
  final String name;
  /// The filter operator to use for matching.
  final FilterOperator op;
  /// The value the property must match.
  final Object value;
}

class FilterOperator {
  // meh, why have it...
  // static const operatorUnspecified = const FilterOperator._("OPERATOR_UNSPECIFIED");
  /// The filter operator will be `entity_property < value`.
  static const lessThan = const FilterOperator._("LESS_THAN");
  /// The filter operator will be `entity_property <= value`.
  static const lessThanOrEqual = const FilterOperator._("LESS_THAN_OR_EQUAL");
  /// The filter operator will be `entity_property > value`.
  static const greaterThan = const FilterOperator._("GREATER_THAN");
  /// The filter operator will be `entity_property >= value`.
  static const greaterThanOrEqual =
      const FilterOperator._("GREATER_THAN_OR_EQUAL");
  /// The filter operator will be `entity_property == value`.
  static const equal = const FilterOperator._("EQUAL");
  /// The left side of this operator must be `__key__` (i.e. the filter can be only used
  /// to match the entity key), and will match if the key on the right as a key path is
  /// a prefix of the key path of the entity key.
  ///
  /// The key path means the chain from the root key down to the entity key backwards via
  /// the parent key references.
  static const hasAncestor = const FilterOperator._("HAS_ANCESTOR");

  static const List<FilterOperator> values = const [
    lessThan,
    lessThanOrEqual,
    greaterThan,
    greaterThanOrEqual,
    equal,
    hasAncestor
  ];

  const FilterOperator._(this.opName);

  /// Can be used to support filter operators that come out in
  /// the future but are not predefined in this library.
  ///
  /// The already existing contants will not be recreated via this
  /// constructor, however it will return a unique object every time
  /// if it is used with a currently unknown operator.
  factory FilterOperator.custom(String opName) =>
    lookup(opName);

  static FilterOperator lookup(String opName) {
    if (_opNameToOp == null) {
      _opNameToOp = {};
      for (FilterOperator op in values) {
        _opNameToOp[op.opName] = op;
      }
    }
    return _opNameToOp[opName] ?? new FilterOperator._(opName);
  }

  /// Convenience way to create a [PropertyFilterPredicate] with the given
  /// [propertyName] and the [propertyValue] to be matched.
  ///
  /// For example:
  ///
  ///     FilterOperator.equal("foo", 5)
  PropertyFilterPredicate call(String propertyName, Object propertyValue) =>
      of(propertyName, propertyValue);
  /// Convenience method to create a [PropertyFilterPredicate] with the given
  /// [propertyName] and the [propertyValue] to be matched.
  ///
  /// For example:
  ///
  ///     FilterOperator.equal.of("foo", 5)
  PropertyFilterPredicate of(String propertyName, Object propertyValue) =>
      new PropertyFilterPredicate(propertyName, this, propertyValue);

  /// Create the API object directly by providing the [propertyName] and the
  /// [propertyValue] to be matched.
  ds.Filter encode(String propertyName, Object propertyValue) =>
      of(propertyName, propertyValue).toApiObject();

  bool operator ==(other) => other is FilterOperator && other.opName == opName;

  int get hashCode => opName.hashCode;

  /// The internal name of the operator.
  final String opName;

  static Map<String, FilterOperator> _opNameToOp;
}

/// Represents a projection that can be added to a query.
class Projection implements ApiRepresentation<ds.Projection> {
  /// Creates a projection on the property named [propertyName],
  /// and distinct values will be returned if [distinct] is set
  /// to `true`.
  const Projection(this.propertyName, {this.distinct: false});

  /// Extracts the list of projections from the API level query object.
  ///
  /// Returns `null` if the projection field is set to `null`, otherwise
  /// it maps the projection name elements and sets their distinctiveness
  /// properly.
  static List<Projection> fromProtocol(ds.Query query) {
    if (query.projection == null) return null;
    Set<String> distinct = null;
    if (query.distinctOn != null && query.distinctOn.isNotEmpty) {
      distinct = query.distinctOn.map((ref) => ref.name).toSet();
    }

    return query.projection.map((p) => new Projection(p.property.name,
        distinct: distinct?.contains(p.property.name) ?? false));
  }

  ds.Projection toApiObject() =>
      new ds.Projection()..property = toPropertyReference();
  ds.PropertyReference toPropertyReference() =>
      new ds.PropertyReference()..name = propertyName;

  /// The name of the property on which the projection should be made.
  final String propertyName;
  /// Set to true whether the query should return distinct results based
  /// on this property.
  final bool distinct;
}

/// Specifies a sorting order to use to return the entities in a query.
class PropertySort implements ApiRepresentation<ds.PropertyOrder> {
  const PropertySort(this.name, this.direction);

  ds.PropertyOrder toApiObject() => new ds.PropertyOrder()
    ..property = (new ds.PropertyReference()..name = name)
    ..direction = direction.name;

  /// The direction the sort.
  final SortDirection direction;
  /// The name of the property that should be sorted on.
  final String name;
}

/// Specifies a sorting direction.
class SortDirection {
  /// Sort ascending.
  static const ascending = const SortDirection._("ASCENDING");
  /// Sort descending.
  static const descending = const SortDirection._("DESCENDING");

  static const List<SortDirection> values = const [ascending, descending];

  /// Look up sort direction by name.
  static SortDirection lookup(String opName) {
    if (_nameToSortDirection == null) {
      _nameToSortDirection = {};
      for (SortDirection op in values) {
        _nameToSortDirection[op.name] = op;
      }
    }
    return _nameToSortDirection[opName] ?? new SortDirection._(opName);
  }

  const SortDirection._(this.name);

  /// Creates a [SortDirection] using a currently unsupported API value,
  /// or returns a currently existing instance if it is already supported.
  factory SortDirection.custom(String name) => lookup(name);

  /// Shorthand to create a custom [PropertySort] object.
  ///
  /// Usage:
  ///
  ///     SortDirection.ascending("name")
  PropertySort call(String propertyName) => of(propertyName);

  /// Shorthand to create a custom [PropertySort] object.
  ///
  /// Usage:
  ///
  ///     SortDirection.ascending.of("name")
  PropertySort of(String propertyName) => new PropertySort(propertyName, this);

  /// Shorthand to creates an API object using on the property named in [propertyName].
  ds.PropertyOrder encode(String propertyName) =>
      of(propertyName).toApiObject();

  bool operator ==(other) => other is SortDirection && other.name == name;

  int get hashCode => name.hashCode;

  /// The API enum name of this sort direction.
  final String name;

  static Map<String, SortDirection> _nameToSortDirection;
}

/// A query for entities.
class Query implements ApiRepresentation<ds.Query> {
  /// Creates a query of the given kind or `null` for kindless queries.
  Query(this.kind);

  /// Creates a query from a `package:googleapis` query object
  factory Query.fromProtocol(ds.Query query) => new Query(query.kind[0].name)
    ..limit = query.limit
    ..offset = query.offset
    ..filter = query.filter?.propertyFilter != null
        ? new PropertyFilterPredicate.fromProtocol(query.filter)
        : query.filter?.compositeFilter != null
            ? new CompoundFilter.fromProtocol(query.filter)
            : null
    ..startCursor = query.startCursor
    ..endCursor = query.endCursor
    ..projection = Projection.fromProtocol(query)
    ..sort = query.order?.map((order) => new PropertySort(
        order.property.name, SortDirection.lookup(order.direction)));

  /// The kind on which the query is going to be performed.
  ///
  /// Set to `null` on kindless queries.
  String kind;

  /// The filter to use on the entities, or `null` if no filter should be applied.
  Filter filter;

  /// The cursor at which the query should stop.
  String endCursor;

  /// The start cursor where the query should begin.
  String startCursor;

  /// The list of projections to apply on the query.
  List<Projection> projection;

  /// The maximum number of entities to return.
  ///
  /// The default value is 1000. Set it to `null` to query all the
  /// possible results.
  int limit = 1000;

  /// The number of entities to skip before returning the results.
  int offset;

  /// Sorting options to add to the query.
  List<PropertySort> sort;

  ds.Query toApiObject() => new ds.Query()
    ..startCursor = startCursor
    ..endCursor = endCursor
    ..projection =
        projection?.map(ApiRepresentation.mapToApi)?.toList(growable: false)
    ..filter = filter?.toApiObject()
    ..kind = kind == null ? null : [new ds.KindExpression()..name = kind]
    ..limit = limit
    ..offset = offset
    ..order = sort?.map(ApiRepresentation.mapToApi)?.toList(growable: false)
    ..distinctOn = projection
        ?.where((p) => p.distinct)
        ?.map((p) => p.toPropertyReference())
        ?.toList(growable: false);

  /// Create a raw API request object with the query field already filled in.
  ds.RunQueryRequest createRequest() =>
      new ds.RunQueryRequest()..query = toApiObject();
}
