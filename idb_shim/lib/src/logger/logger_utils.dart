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
  try {
    return logTruncate(value?.toString() ?? '<null>', len: 128);
  } catch (e) {
    try {
      return 'log_error_${logTruncate(e.toString())}';
    } catch (e2) {
      return 'log_error (len=$len)';
    }
  }
}

String logTruncate(String text, {int len = 128}) {
  if (text.length > len) {
    text = text.substring(0, len);
  }
  return text;
}
