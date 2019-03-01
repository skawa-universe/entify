/// Every class in entify that can be represented with a `package:googleapis` object
/// implement this interface.
abstract class ApiRepresentation<T> {
  T toApiObject();

  /// A method that can be used in `Iterable.map` to generate a list of API objects.
  static T mapToApi<T>(ApiRepresentation<T> element) => element.toApiObject();
}
