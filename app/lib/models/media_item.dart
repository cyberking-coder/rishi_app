enum MediaType { video, audio }

class MediaItem {
  final int id;
  final String title;
  final String? description;
  final MediaType type;
  final String? thumbnailUrl;
  final int? durationSecs;
  final bool isDownloadable;

  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.description,
    this.thumbnailUrl,
    this.durationSecs,
    this.isDownloadable = false,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: (json['mediaType'] as String) == 'audio'
          ? MediaType.audio
          : MediaType.video,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      durationSecs: json['durationSecs'] as int?,
      isDownloadable: json['isDownloadable'] as bool? ?? false,
    );
  }
}
