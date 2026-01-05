import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../services/audio_manager.dart';
import '../widgets/mini_player.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist; // Riceve la playlist dalla Home

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
    // Aggiungiamo il listener per aggiornare la UI se cambia la canzone
    _audioManager.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // Filtra i brani della playlist corrente in base alla ricerca
  List<Track> get filteredTracks {
    if (_searchText.isEmpty) return widget.playlist.tracks;
    
    return widget.playlist.tracks.where((track) {
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            // Torna alla Home
            onPressed: () => Navigator.pop(context), 
          ),
        ),
        title: _isSearching
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Cerca brano...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchText = value),
                ),
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
              onPressed: _isSearching ? _stopSearch : _startSearch,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Header con gradiente e immagine (Mostrato solo se non si sta cercando)
          if (!_isSearching)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.withOpacity(0.8),
                    const Color(0xFF121212)
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60), // Spazio per l'AppBar
                  Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.playlist.imageUrl != null && widget.playlist.imageUrl!.isNotEmpty
                          ? Image.network(
                              widget.playlist.imageUrl!,
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                            )
                          : _buildPlaceholderImage(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.playlist.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Spazio compensativo per l'AppBar quando si cerca (per non coprire la lista)
          if (_isSearching) const SizedBox(height: 100),

          // Lista dei brani
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: filteredTracks.isEmpty
                  ? Center(
                      child: Text(
                        _isSearching ? "Nessun risultato" : "Questa playlist è vuota",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = filteredTracks[index];
                        final isCurrent = _audioManager.currentTrack?.name == track.name; // Confronto per nome o oggetto

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Text(
                            "${index + 1}",
                            style: TextStyle(
                              color: isCurrent ? Colors.green : Colors.grey,
                              fontSize: 16,
                            ),
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
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          trailing: isCurrent && _audioManager.isPlaying
                              ? const Icon(Icons.volume_up, color: Colors.green, size: 20)
                              : null,
                          onTap: () {
                            // Imposta la coda usando la lista filtrata
                            _audioManager.setQueue(filteredTracks, index);
                            FocusScope.of(context).unfocus(); // Chiude la tastiera se aperta
                          },
                        );
                      },
                    ),
            ),
          ),
          
          // Player ridotto in basso
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[800],
      width: 160,
      height: 160,
      child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
    );
  }
}