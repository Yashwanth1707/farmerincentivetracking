typedef JsonMap = Map<String, dynamic>;

List<JsonMap> extractRows(dynamic value) {
  if (value == null) return [];

  // Already a list
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // Paginated response
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);

    if (map["data"] is List) {
      return (map["data"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (map["rows"] is List) {
      return (map["rows"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  return [];
}

JsonMap asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return {};
}

List<JsonMap> asList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return [];
}

dynamic valueAt(dynamic source, String path) {
  dynamic current = source;

  for (final part in path.split('.')) {
    if (current is Map) {
      current = current[part];
    } else {
      return null;
    }
  }

  return current;
}