import '../../../core/network/api_client.dart';
import '../domain/models/body_weight_entry.dart';
import '../domain/models/profile_details.dart';
import '../domain/repositories/body_weight_repository.dart';

class ApiBodyWeightRepository implements BodyWeightRepository {
  ApiBodyWeightRepository(this._api);

  final ApiClient _api;

  static const _path = '/profile/me/body-weight';

  @override
  Future<List<BodyWeightEntry>> list({int limit = 1000}) async {
    final data =
        await _api.get('$_path?limit=$limit', auth: true)
            as Map<String, dynamic>;
    final entries =
        (data['entries'] as List<dynamic>? ?? const [])
            .map((e) => BodyWeightEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  @override
  Future<BodyWeightEntry> save(DateTime date, double weightKg) async {
    final data = await _api.put('$_path/${formatIsoDate(date)}', {
      'weightKg': weightKg,
    }, auth: true);
    return BodyWeightEntry.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> delete(DateTime date) async {
    try {
      await _api.delete('$_path/${formatIsoDate(date)}', auth: true);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }
}
