import 'dart:convert';
import 'dart:async'; // Serve per gli Stream (tempo e durata)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Serve per leggere il JSON dagli assets
import 'package:just_audio/just_audio.dart'; // Il player audio
import 'package:youtube_explode_dart/youtube_explode_dart.dart'; // L'interfaccia con YouTube

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.green,
          thumbColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        ),
      ),
      home: const PlaylistScreen(),
    );
  }
}

// --- 1. I MODELLI DEI DATI (Invariati) ---
class Track {
  final String name;
  final String artist;
  final String album;
  final String searchQuery;
  // Aggiungiamo un campo opzionale per l'immagine che recupereremo da YouTube
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
  final List<Track> tracks;

  Playlist({required this.id, required this.name, required this.tracks});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var list = json['tracks'] as List;
    List<Track> tracksList = list.map((i) => Track.fromJson(i)).toList();
    return Playlist(
      id: json['id'],
      name: json['name'],
      tracks: tracksList,
    );
  }
}

// --- 2. IL MOTORE AUDIO AVANZATO (Modificato per JSON) ---
class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  // CODA E STATO
  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;

  // GETTERS
  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // Imposta la playlist e inizia a suonare dalla traccia selezionata
  Future<void> setQueue(List<Track> tracks, int initialIndex) async {
    _queue = List.from(tracks);
    _currentIndex = initialIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final track = _queue[_currentIndex];
      print("CERCO SU YOUTUBE: ${track.searchQuery}");

      var searchList = await _yt.search.search(track.searchQuery);
      if (searchList.isEmpty) return;
      var video = searchList.first;

      // Salviamo la thumbnail per mostrarla nel player
      track.runtimeThumbnail = video.thumbnails.lowResUrl;

      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      dynamic streamInfo;

      // LOGICA MP4 (Quella robusta che abbiamo fatto prima)
      try {
        var mp4Streams = manifest.muxed.where(
          (s) => s.container.name.toString().toLowerCase().contains('mp4')
        ).toList();
        
        if (mp4Streams.isNotEmpty) {
           mp4Streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
           streamInfo = mp4Streams.first;
        } else {
           throw Exception("Nessun MP4");
        }
      } catch (e) {
        streamInfo = manifest.muxed.first; 
      }

      var url = streamInfo.url.toString();

      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        },
      ));

      _player.play();
    } catch (e) {
      print("ERRORE: $e");
      next(); // Se fallisce, prova la prossima
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // CONTROLLI
  void togglePlayPause() {
    if (_player.playing) _player.pause();
    else _player.play();
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    }
  }

  void previous() {
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _playCurrent();
    }
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  void stop() {
    _player.stop();
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();
  }
}

// --- 3. UI (Modificata per usare AudioManager) ---
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> playlists = [];
  final AudioManager _audioManager = AudioManager(); // Singleton
  
  bool isLoading = true;
  Playlist? selectedPlaylist;

  @override
  void initState() {
    super.initState();
    loadPlaylists();
    
    // Ascolta la fine della canzone per andare avanti
    _audioManager.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _audioManager.next();
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> loadPlaylists() async {
    try {
      final String response = await rootBundle.loadString('assets/music_data.json');
      final data = await json.decode(response) as List;
      setState(() {
        playlists = data.map((e) => Playlist.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Errore lettura JSON: $e");
      // Dati di fallback se il JSON non esiste
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // LISTA DELLE PLAYLIST
    if (selectedPlaylist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Le mie Playlist")),
        body: ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final pl = playlists[index];
            return ListTile(
              leading: const Icon(Icons.folder, color: Colors.green, size: 40),
              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text("${pl.tracks.length} brani", style: const TextStyle(color: Colors.grey)),
              onTap: () => setState(() => selectedPlaylist = pl),
            );
          },
        ),
        // Mostriamo il MiniPlayer anche qui
        bottomNavigationBar: const MiniPlayer(),
      );
    }

    // DENTRO UNA PLAYLIST
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => selectedPlaylist = null),
        ),
        title: Text(selectedPlaylist!.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: selectedPlaylist!.tracks.length,
              itemBuilder: (context, index) {
                final track = selectedPlaylist!.tracks[index];
                // Controllo se è la canzone corrente per colorarla di verde
                final isCurrent = _audioManager.currentTrack == track;
                
                return ListTile(
                  leading: Icon(
                    isCurrent && _audioManager.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: isCurrent ? Colors.green : Colors.white,
                  ),
                  title: Text(track.name, 
                    style: TextStyle(color: isCurrent ? Colors.green : Colors.white, fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(track.artist, style: const TextStyle(color: Colors.grey)),
                  onTap: () {
                    // QUI PASSIAMO TUTTA LA LISTA AL MANAGER
                    _audioManager.setQueue(selectedPlaylist!.tracks, index);
                  },
                );
              },
            ),
          ),
          const MiniPlayer(), // Il player fisso in basso
        ],
      ),
    );
  }
}

// --- 4. WIDGET MINI PLAYER (NUOVO E COMPLETO) ---
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // Usiamo AnimatedBuilder per aggiornare la grafica quando cambia la canzone
    return AnimatedBuilder(
      animation: AudioManager(),
      builder: (context, child) {
        final manager = AudioManager();
        final track = manager.currentTrack;

        if (track == null) return const SizedBox.shrink(); // Nascondi se non c'è musica

        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CONTROLLI E INFO
              ListTile(
                // Mostra thumbnail se c'è, altrimenti icona
                leading: track.runtimeThumbnail != null 
                  ? Image.network(track.runtimeThumbnail!, width: 50, fit: BoxFit.cover)
                  : const Icon(Icons.music_note, size: 40, color: Colors.grey),
                title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(track.artist),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous), onPressed: manager.previous),
                    IconButton(
                      icon: manager.isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(manager.isPlaying ? Icons.pause_circle : Icons.play_circle, size: 40, color: Colors.green),
                      onPressed: manager.togglePlayPause,
                    ),
                    IconButton(icon: const Icon(Icons.skip_next), onPressed: manager.next),
                  ],
                ),
              ),
              
              // BARRA DI PROGRESSO (Slider)
              StreamBuilder<Duration>(
                stream: manager.positionStream,
                builder: (context, snapPos) {
                  final pos = snapPos.data ?? Duration.zero;
                  return StreamBuilder<Duration?>(
                    stream: manager.durationStream,
                    builder: (context, snapDur) {
                      final duration = snapDur.data ?? Duration.zero;
                      final maxSec = duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0;
                      final val = pos.inSeconds.toDouble().clamp(0.0, maxSec);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(_format(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Expanded(
                              child: Slider(
                                min: 0.0,
                                max: maxSec,
                                value: val,
                                onChanged: (v) => manager.seek(Duration(seconds: v.toInt())),
                              ),
                            ),
                            Text(_format(duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}