import 'dart:convert';
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const PlaylistScreen(),
    );
  }
}

// --- 1. I MODELLI DEI DATI ---
// Queste classi servono a trasformare il JSON in oggetti Dart utilizzabili
class Track {
  final String name;
  final String artist;
  final String album;
  final String searchQuery;

  Track({
    required this.name,
    required this.artist,
    required this.album,
    required this.searchQuery,
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

// --- 2. IL MOTORE AUDIO ---
// Questa classe gestisce la logica "sporca": cerca su YT e riproduce
class AudioPlayerService {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();

Future<void> playTrack(String searchQuery) async {
    try {
      print("CERCO SU YOUTUBE: $searchQuery");
      
      var searchList = await _yt.search.search(searchQuery);
      if (searchList.isEmpty) return;
      var video = searchList.first;

      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      dynamic streamInfo;
      
      // LOGICA COMPATIBILE VERSIONE 3.0.5
      // Non usiamo più le scorciatoie .withLowestBitrate() che non esistono più.
      
      try {
        // 1. Filtra: prendi solo quelli che sono MP4
        var mp4Streams = manifest.muxed.where(
          (s) => s.container.name.toString().toLowerCase().contains('mp4')
        ).toList();
        
        if (mp4Streams.isNotEmpty) {
           // 2. Ordina: dal più piccolo al più grande (per risparmiare dati e caricare veloce)
           mp4Streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
           
           // 3. Prendi il primo (il più leggero)
           streamInfo = mp4Streams.first;
           print("TROVATO MP4 (Versione 3.0)");
        } else {
           throw Exception("Nessun MP4");
        }

      } catch (e) {
        // Fallback: Se non trova MP4, prendi il primo stream disponibile nella lista muxed
        print("Fallback: Prendo il primo stream disponibile");
        // .first funziona sempre su tutte le liste
        streamInfo = manifest.muxed.first; 
      }

      var url = streamInfo.url.toString();
      print("URL: $url");

      // HEADER MASCHERATI (User-Agent Mobile)
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        },
      ));
      
      _player.play();
      
    } catch (e) {
      print("ERRORE CRITICO: $e");
    }
  }

  void stop() => _player.stop();
  
  // Chiude tutto quando l'app si chiude per liberare memoria
  void dispose() {
    _player.dispose();
    _yt.close();
  }
}

// --- 3. L'INTERFACCIA UTENTE (UI) ---
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> playlists = [];
  final AudioPlayerService _audioService = AudioPlayerService();
  
  bool isLoading = true;       // Stiamo caricando il JSON?
  Playlist? selectedPlaylist;  // Quale playlist sta guardando l'utente?
  Track? currentTrack;         // Quale canzone sta suonando?

  @override
  void initState() {
    super.initState();
    loadPlaylists();
  }

  // Carica il file JSON dalla cartella assets
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
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Schermata di caricamento
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // VISTA 1: LISTA DELLE PLAYLIST
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
              onTap: () {
                // Quando clicco, imposto la playlist selezionata
                setState(() {
                  selectedPlaylist = pl;
                });
              },
            );
          },
        ),
      );
    }

    // VISTA 2: DENTRO UNA PLAYLIST (LISTA BRANI)
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => selectedPlaylist = null), // Torna indietro
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
                final isPlaying = currentTrack == track;
                
                return ListTile(
                  leading: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: isPlaying ? Colors.green : Colors.white,
                    size: 30,
                  ),
                  title: Text(track.name, 
                    style: TextStyle(
                      color: isPlaying ? Colors.green : Colors.white,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  subtitle: Text(track.artist, style: const TextStyle(color: Colors.grey)),
                  onTap: () async {
                    // Clicco su una canzone
                     setState(() => currentTrack = track);
                     // Avvio lo streaming
                     await _audioService.playTrack(track.searchQuery);
                  },
                );
              },
            ),
          ),
          
          // MINI PLAYER (barra in basso se c'è musica)
          if (currentTrack != null)
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text("In riproduzione: ${currentTrack!.name} - ${currentTrack!.artist}", 
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.red),
                      onPressed: () {
                        _audioService.stop();
                        setState(() => currentTrack = null);
                      },
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}