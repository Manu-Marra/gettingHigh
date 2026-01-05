import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_models.dart';
import '../services/music_service.dart';
import '../services/playlist_import_service.dart';
import 'playlist_screen.dart'; // Assicurati di avere questo file per la navigazione

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variabile per gestire il caricamento dei dati
  late Future<List<Playlist>> _playlistsFuture;
  final MusicService _musicService = MusicService();

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  // Funzione per caricare (o ricaricare) le playlist
  void _loadPlaylists() {
    setState(() {
      _playlistsFuture = _musicService.getPlaylists();
    });
  }

  // 1. Apre il sito Exportify nel browser
  Future<void> _launchExportify() async {
    final Uri url = Uri.parse('https://exportify.net');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Impossibile lanciare $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore apertura link: $e')),
      );
    }
  }

  // 2. Gestisce l'importazione dello ZIP
  Future<void> _handleImportZip() async {
    // Chiude il dialog se aperto
    Navigator.of(context).pop(); 

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleziona il file .zip scaricato...')),
    );

    // Chiama il nostro servizio di importazione
    bool success = await PlaylistImportService().importPlaylistsFromZip();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Importazione completata! Aggiorno la lista...')),
      );
      // Ricarica la UI per mostrare le nuove playlist
      _loadPlaylists();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Importazione annullata o fallita.')),
      );
    }
  }

  // Mostra il popup per guidare l'utente
  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Importa da Spotify", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Segui questi passaggi:\n\n"
          "1. Vai su Exportify e fai il login.\n"
          "2. Clicca su 'Export All' per scaricare lo ZIP.\n"
          "3. Torna qui e seleziona il file ZIP appena scaricato.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.web),
            label: const Text("1. Vai su Exportify"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _launchExportify,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_zip),
            label: const Text("2. Seleziona ZIP"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: _handleImportZip,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Le mie Playlist"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Importa Playlist',
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("Nessuna playlist trovata.", style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: _showImportDialog,
                    child: const Text("Importa ora da Spotify"),
                  )
                ],
              ),
            );
          }

          final playlists = snapshot.data!;

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              
              // Gestione immagine (Placeholder se vuota)
              Widget imageWidget;
              if (playlist.imageUrl != null && playlist.imageUrl!.isNotEmpty) {
                imageWidget = Image.network(playlist.imageUrl!, fit: BoxFit.cover);
              } else {
                imageWidget = Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, color: Colors.white54),
                );
              }

              return ListTile(
                leading: SizedBox(
                  width: 50, height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageWidget,
                  ),
                ),
                title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${playlist.tracks.length} brani", style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  // Navigazione verso la schermata di dettaglio
                  // Assumiamo che PlaylistScreen accetti l'oggetto playlist
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