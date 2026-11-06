import 'package:flutter_test/flutter_test.dart';
import 'package:udi_shopping/api_service.dart';

void main() {
  test('API base URL defaults to the Android emulator host', () {
    expect(
      ApiService.baseUrl,
      'http://10.0.2.2:8000/api/v1',
    );
  });
}
