// ignore_for_file: public_member_api_docs

String getPropertyValueText(
  String property,
  String value, [
  bool addComma = false,
]) {
  return '${addComma ? ', ' : ''}$property: $value';
}

String getPropertyMapText(Map map, [bool addComma = false]) {
  return '${addComma ? ', ' : ''}$map';
}

String logTruncateAny(Object? value, {int len = 128}) {
  return logTruncate(value?.toString() ?? '<null>', len: 128);
}

String logTruncate(String text, {int len = 128}) {
  if (text.length > len) {
    text = text.substring(0, len);
  }
  return text;
}
