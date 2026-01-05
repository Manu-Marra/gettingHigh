import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_models.dart';
import '../services/music_service.dart';
import '../services/playlist_import_service.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Playlist>> _playlistsFuture;
  final MusicService _musicService = MusicService();

  // --- LOGICA RICERCA ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() {
    setState(() {
      _playlistsFuture = _musicService.getPlaylists();
    });
  }

  // Gestione apertura/chiusura ricerca
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

  Future<void> _launchExportify() async {
    final Uri url = Uri.parse('https://exportify.net');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Impossibile lanciare $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _handleImportZip() async {
    Navigator.of(context).pop(); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleziona il file .zip scaricato...')),
    );

    bool success = await PlaylistImportService().importPlaylistsFromZip();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Importazione completata!')),
      );
      _loadPlaylists();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Importazione annullata o fallita.')),
      );
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Importa da Spotify", style: TextStyle(color: Colors.white)),
        content: const Text(
          "1. Vai su Exportify e Login.\n2. Scarica 'Export All' (Zip).\n3. Carica lo Zip qui.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          ElevatedButton(onPressed: _launchExportify, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("1. Sito")),
          ElevatedButton(onPressed: _handleImportZip, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: const Text("2. Carica Zip")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Se stiamo cercando mostra il campo di testo, altrimenti il titolo
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Cerca playlist...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              )
            : const Text("Le mie Playlist"),
        actions: [
          // Tasto Cerca (o Chiudi Cerca)
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              if (_isSearching) {
                _stopSearch();
              } else {
                _startSearch();
              }
            },
          ),
          // Tasto Importa (visibile solo se non cerchi)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Importa',
              onPressed: _showImportDialog,
            ),
        ],
      ),
      body: FutureBuilder<List<Playlist>>(
        future: _playlistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Errore: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nessuna playlist. Importane una!", style: TextStyle(color: Colors.grey)));
          }

          final allPlaylists = snapshot.data!;
          
          // FILTRO LISTA: Se c'è testo di ricerca, filtriamo qui
          final displayedPlaylists = _searchText.isEmpty
              ? allPlaylists
              : allPlaylists.where((p) => p.name.toLowerCase().contains(_searchText.toLowerCase())).toList();

          if (displayedPlaylists.isEmpty) {
            return const Center(child: Text("Nessuna playlist trovata con questo nome.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: displayedPlaylists.length,
            itemBuilder: (context, index) {
              final playlist = displayedPlaylists[index];
              
              Widget imageWidget;
              if (playlist.imageUrl != null && playlist.imageUrl!.isNotEmpty) {
                imageWidget = Image.network(playlist.imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note)));
              } else {
                imageWidget = Container(color: Colors.grey[800], child: const Icon(Icons.music_note, color: Colors.white54));
              }

              return ListTile(
                leading: SizedBox(
                  width: 50, height: 50,
                  child: ClipRRect(borderRadius: BorderRadius.circular(4), child: imageWidget),
                ),
                title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${playlist.tracks.length} brani", style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  // Quando clicco, fermo la ricerca nella home e vado al dettaglio
                  _stopSearch(); 
                  Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => PlaylistScreen(playlist: playlist),
                     ),
                   );
                },
              );
            },
          );
        },
      ),
    );
  }
}