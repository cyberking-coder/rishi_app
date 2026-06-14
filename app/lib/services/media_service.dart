import '../models/media_item.dart';
import 'api_service.dart';

class MediaService {
  final ApiService api;
  MediaService(this.api);

  Future<List<MediaItem>> list({MediaType? type}) async {
    final query = <String, String>{};
    if (type != null) {
      query['type'] = type == MediaType.audio ? 'audio' : 'video';
    }
    final res = await api.get('/media', query: query.isEmpty ? null : query);
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    return items.map(MediaItem.fromJson).toList();
  }
}
