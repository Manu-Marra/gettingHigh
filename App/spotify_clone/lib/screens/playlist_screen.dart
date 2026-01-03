
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/data_models.dart';
import '../services/audio_manager.dart';
import '../widgets/mini_player.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> playlists = [];
  final AudioManager _audioManager = AudioManager();
  bool isLoading = true;
  Playlist? selectedPlaylist;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    loadPlaylists();
    _audioManager.addListener(() {
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
      setState(() => isLoading = false);
    }
  }

  List<Playlist> get filteredPlaylists {
    if (_searchText.isEmpty) return playlists;
    return playlists.where((pl) => pl.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
  }

  List<Track> get filteredTracks {
    if (selectedPlaylist == null) return [];
    if (_searchText.isEmpty) return selectedPlaylist!.tracks;
    return selectedPlaylist!.tracks.where((track) {
      return track.name.toLowerCase().contains(_searchText.toLowerCase()) ||
             track.artist.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  void _startSearch() => setState(() => _isSearching = true);
  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchText = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    AppBar buildAppBar(String title, {VoidCallback? onBack}) {
      return AppBar(
        leading: onBack != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          : (_isSearching ? const Icon(Icons.search) : null),
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Cerca...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
              onChanged: (value) => setState(() => _searchText = value),
            )
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: !_isSearching,
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        ],
      );
    }

    if (selectedPlaylist == null) {
      return Scaffold(
        appBar: buildAppBar("Le mie Playlist"),
        body: ListView.builder(
          itemCount: filteredPlaylists.length,
          itemBuilder: (context, index) {
            final pl = filteredPlaylists[index];
            return ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: pl.imageUrl != null 
                  ? Image.network(pl.imageUrl!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[800], width: 60, height: 60, child: const Icon(Icons.music_note)))
                  : Container(width: 60, height: 60, color: Colors.grey[800], child: const Icon(Icons.folder_open, color: Colors.green, size: 30)),
              ),
              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Playlist • ${pl.tracks.length} brani"),
              onTap: () { _stopSearch(); setState(() => selectedPlaylist = pl); },
            );
          },
        ),
        bottomNavigationBar: const MiniPlayer(),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { _stopSearch(); setState(() => selectedPlaylist = null); }),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
          )
        ],
      ),
      body: Column(
        children: [
          if (!_isSearching)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green.withOpacity(0.8), const Color(0xFF121212)])),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Container(
                    decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0,10))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedPlaylist!.imageUrl != null
                        ? Image.network(selectedPlaylist!.imageUrl!, width: 160, height: 160, fit: BoxFit.cover)
                        : Container(color: Colors.grey[800], width: 160, height: 160, child: const Icon(Icons.music_note, size: 80)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isSearching)
                     const SizedBox()
                  else
                     Text(selectedPlaylist!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                ],
              ),
            ),
          
          if (_isSearching) const SizedBox(height: 100),

          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: filteredTracks.isEmpty 
                ? const Center(child: Text("Nessun risultato", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      final isCurrent = _audioManager.currentTrack == track;
                      
                      return ListTile(
                        leading: Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        title: Text(track.name, style: TextStyle(color: isCurrent ? Colors.green : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(track.artist),
                        trailing: isCurrent && _audioManager.isPlaying ? const Icon(Icons.volume_up, color: Colors.green, size: 20) : null,
                        onTap: () {
                          _audioManager.setQueue(filteredTracks, index);
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
