import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/constants/api_constants.dart';
import 'package:gym/core/network/api_asset_uri.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ApiClient base URL is <origin>/api/v1', () {
    expect(kApiBaseUrl, '$kApiOrigin/api/v1');
    expect(apiBaseUrlFor('http://host:3000'), 'http://host:3000/api/v1');
    expect(apiBaseUrlFor('http://host:3000/'), 'http://host:3000/api/v1');
  });

  test('upload paths resolve against the bare origin, not /api/v1', () {
    expect(
      apiAssetUri('/uploads/avatars/a.png').toString(),
      '$kApiOrigin/uploads/avatars/a.png',
    );
    expect(
      apiAssetUri('/uploads/x.png', baseUrl: 'http://h:1').toString(),
      'http://h:1/uploads/x.png',
    );
    expect(
      apiAssetUri('https://cdn/x.png').toString(),
      'https://cdn/x.png',
    );
    expect(apiAssetUri(''), isNull);
  });

  test('history read and session write paths go through /api/v1', () async {
    final paths = <String>[];
    final api = http.runWithClient(
      () => ApiClient(
        baseUrl: apiBaseUrlFor('http://api'),
        getToken: () async => 't',
      ),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '{"items":[],"nextCursor":null,"hasMore":false}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await TrainingHistoryRemoteDataSource(api).getSessions();
    await TrainingSessionRemoteDataSource(api).history();

    expect(paths, [
      '/api/v1/training-sessions',
      '/api/v1/training-sessions/history',
    ]);
  });
}
