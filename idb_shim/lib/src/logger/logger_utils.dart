String getPropertyValueText(String property, String value,
    [bool addComma = false]) {
  return '${addComma ? ', ' : ''}$property: $value';
}

String getPropertyMapText(Map map, [bool addComma = false]) {
  return '${addComma ? ', ' : ''}$map';
}
