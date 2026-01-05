import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../services/audio_manager.dart';
import '../widgets/mini_player.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioManager _audioManager = AudioManager();
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _audioManager.addListener(_update);
  }

  @override
  void dispose() {
    _audioManager.removeListener(_update);
    _searchController.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  // Logica di filtraggio
  List<Track> get filteredTracks {
    if (_searchText.isEmpty) return widget.playlist.tracks;
    
    return widget.playlist.tracks.where((track) {
      final query = _searchText.toLowerCase();
      return track.name.toLowerCase().contains(query) ||
             track.artist.toLowerCase().contains(query);
    }).toList();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }
  
  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchText = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calcoliamo la lista filtrata una volta per build
    final currentTracks = filteredTracks;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _isSearching ? const Color(0xFF121212) : Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), 
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.green, // Colore cursore Spotify
                decoration: const InputDecoration(
                  hintText: "Cerca brano...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              )
            : null, // Nessun titolo se non si cerca (l'immagine fa da titolo)
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: _isSearching ? _stopSearch : _startSearch,
          )
        ],
      ),
      body: Column(
        children: [
          // Header Gradiente (Nascosto se cerchiamo per dare spazio ai risultati)
          if (!_isSearching)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green.withOpacity(0.8), const Color(0xFF121212)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Container(
                    decoration: const BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.playlist.imageUrl != null && widget.playlist.imageUrl!.isNotEmpty
                          ? Image.network(
                              widget.playlist.imageUrl!,
                              width: 160, height: 160, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.playlist.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Spazio per AppBar quando si cerca
          if (_isSearching) const SizedBox(height: kToolbarHeight + 30),

          // LISTA CANZONI
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: currentTracks.isEmpty
                  ? Center(
                      child: Text(
                        _searchText.isNotEmpty ? "Nessun risultato" : "Playlist vuota",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: currentTracks.length,
                      itemBuilder: (context, index) {
                        final track = currentTracks[index];
                        final isCurrent = _audioManager.currentTrack?.name == track.name;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          leading: Text(
                            "${index + 1}",
                            style: TextStyle(color: isCurrent ? Colors.green : Colors.grey, fontSize: 16),
                          ),
                          title: Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? Colors.green : Colors.white,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                          trailing: isCurrent && _audioManager.isPlaying
                              ? const Icon(Icons.volume_up, color: Colors.green, size: 20)
                              : null,
                          onTap: () {
                            // IMPORTANTE: Passiamo la lista FILTRATA come coda
                            // Se cerco "Amore", la coda sarà solo le canzoni con "Amore"
                            _audioManager.setQueue(currentTracks, index);
                            FocusScope.of(context).unfocus(); // Chiude tastiera
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

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      width: 160, height: 160,
      child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
    );
  }
}