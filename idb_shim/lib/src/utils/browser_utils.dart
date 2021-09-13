// ignore_for_file: public_member_api_docs

library idb_shim.src.utils.browser_utils;

import 'dart:html';

//
// Dart vs Javascript detection
//
bool get _isDartVm => !_isJavascriptVm;

bool get _isJavascriptVm => identical(1.0, 1);

bool? __isDartVm;

bool get isDartVm => __isDartVm ??= _isDartVm;

bool isUserAgentIe(String userAgent) {
  // Yoga IE 11: Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; Touch; .NET4.0C; .NET4.0E; .NET CLR 2.0.50727; .NET CLR 3.0.30729; .NET CLR 3.5.30729; Tablet PC 2.0; MALNJS; rv:11.0) like Gecko
  return userAgent.contains('Trident');
}

bool isUserAgentEdge(String userAgent) {
  // Yoga Edge 12: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.10240
  return userAgent.contains('Edge');
}

bool? _isEdge;

bool get isEdge => _isEdge ?? isUserAgentEdge(window.navigator.userAgent);

bool? _isIe;

bool get isIe => _isIe ?? isUserAgentIe(window.navigator.userAgent);
