import '../models/body_gender.dart';
import '../models/body_model_data.dart';
import '../models/body_view.dart';
import 'body_highlighter_asset_loader.dart';

/// Legacy service adapter redirecting calls to [BodyHighlighterAssetLoader].
class BodyDataService {
  static final BodyDataService _instance = BodyDataService._();
  factory BodyDataService() => _instance;
  BodyDataService._();

  Future<BodyModelData> loadBodyData(
    BodyView view, {
    BodyGender gender = BodyGender.male,
  }) {
    return BodyHighlighterAssetLoader.instance.loadModelData(gender, view);
  }

  void clearCache() {
    BodyHighlighterAssetLoader.instance.clearCache();
  }
}
