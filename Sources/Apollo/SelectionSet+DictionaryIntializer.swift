import ApolloAPI

public enum RootSelectionSetInitializeError: Error {
  case hasNonHashableValue
}

extension RootSelectionSet {
  /// Initializes a `SelectionSet` with a raw JSON response object.
  ///
  /// The process of converting a JSON response into `SelectionSetData` is done by using a
  /// `GraphQLExecutor` with a`GraphQLSelectionSetMapper` to parse, validate, and transform
  /// the JSON response data into the format expected by `SelectionSet`.
  ///
  /// - Parameters:
  ///   - data: A dictionary representing a JSON response object for a GraphQL object.
  ///   - variables: [Optional] The operation variables that would be used to obtain
  ///                the given JSON response data.
  @_disfavoredOverload
  public init(
    data: [String: Any],
    variables: GraphQLOperation.Variables? = nil
  ) async throws {
    let jsonObject = try Self.convertToAnyHashableValueDict(dict: data)
    try await self.init(data: jsonObject, variables: variables)
  }
  
  /// Convert dictionary type [String: Any] to [String: AnyHashable]
  /// - Parameter dict: [String: Any] type dictionary
  /// - Returns: converted [String: AnyHashable] type dictionary
  private static func convertToAnyHashableValueDict(dict: [String: Any]) throws -> JSONObject {
    var result = JSONObject()

    for (key, value) in dict {
      if let arrayValue = value as? [Any] {
        result[key] = try convertToAnyHashableArray(array: arrayValue) as JSONValue
      } else  {
        if let dictValue = value as? [String: Any] {
          result[key] = try convertToAnyHashableValueDict(dict: dictValue) as JSONValue
        } else if let hashableValue = value as? any Hashable {
          result[key] = Self.asJSONValue(hashableValue)
        } else {
          throw RootSelectionSetInitializeError.hasNonHashableValue
        }
      }
    }
    return result
  }

  /// Convert Any type Array type to AnyHashable type Array
  /// - Parameter array: Any type Array
  /// - Returns: AnyHashable type Array
  private static func convertToAnyHashableArray(array: [Any]) throws -> [JSONValue] {
    var result: [JSONValue] = []
    for value in array {
      if let array = value as? [Any] {
        result.append(try convertToAnyHashableArray(array: array) as JSONValue)
      } else if let dict = value as? [String: Any] {
        result.append(try convertToAnyHashableValueDict(dict: dict) as JSONValue)
      } else if let hashable = value as? any Hashable {
        result.append(Self.asJSONValue(hashable))
      } else {
        throw RootSelectionSetInitializeError.hasNonHashableValue
      }
    }
    return result
  }

  /// Bridges a `Hashable` value to `JSONValue` (`any Sendable & Hashable`).
  ///
  /// `JSONValue` requires `Sendable`, but `Sendable` is a marker protocol with no
  /// runtime metadata, so a value of unknown static type cannot be cast to it via
  /// `as?`/`as`. Because a marker protocol contributes no witness table, `any Hashable`
  /// and `any Sendable & Hashable` are runtime-layout-identical, so reinterpreting the
  /// bits is sound, ARC-safe, and preserves the underlying value (verified for value and
  /// reference types). Replaces the previous `as JSONValue` coercion, which relied on
  /// `AnyHashable: Sendable` — a conformance that is no longer available on newer Swift
  /// toolchains.
  private static func asJSONValue(_ value: any Hashable) -> JSONValue {
    unsafeBitCast(value, to: JSONValue.self)
  }
}
