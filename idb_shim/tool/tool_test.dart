import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';

Version parsePlatformVersion(String text) {
  return Version.parse(text.split(' ').first);
}

void main() {
  test('parsePlatformVersion', () {
    expect(
        parsePlatformVersion(
            '2.3.0-dev.0.3 (Tue Apr 23 12:02:59 2019 -0700) on "linux_x64"'),
        Version(2, 3, 0, pre: 'dev.0.3'));
  });
}
