// ignore_for_file: public_member_api_docs

String getPropertyValueText(String property, String value,
    [bool addComma = false]) {
  return '${addComma ? ', ' : ''}$property: $value';
}

String getPropertyMapText(Map map, [bool addComma = false]) {
  return '${addComma ? ', ' : ''}$map';
}

String logTruncateAny(Object? value) {
  return logTruncate(value?.toString() ?? '<null>');
}

String logTruncate(String text, {int len = 128}) {
  if (text.length > len) {
    text = text.substring(0, len);
  }
  return text;
}
