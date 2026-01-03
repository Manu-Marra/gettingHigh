
enum LoopModeState { off, all, one }

class Track {
  final String name;
  final String artist;
  final String album;
  final String searchQuery;
  String? runtimeThumbnail; 

  Track({
    required this.name,
    required this.artist,
    required this.album,
    required this.searchQuery,
    this.runtimeThumbnail,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      name: json['name'] ?? 'Sconosciuto',
      artist: json['artist'] ?? 'Sconosciuto',
      album: json['album'] ?? '',
      searchQuery: json['search_query'] ?? '',
    );
  }
}

class Playlist {
  final String id;
  final String name;
  final String? imageUrl;
  final List<Track> tracks;

  Playlist({
    required this.id, 
    required this.name, 
    this.imageUrl, 
    required this.tracks
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var list = json['tracks'] as List;
    List<Track> tracksList = list.map((i) => Track.fromJson(i)).toList();
    
    String? img;
    if (json['image'] != null && json['image'].toString().trim().isNotEmpty) {
      img = json['image'];
    }

    return Playlist(
      id: json['id'].toString(),
      name: json['name'],
      imageUrl: img,
      tracks: tracksList,
    );
  }
}
