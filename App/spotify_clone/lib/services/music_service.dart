import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // Per caricare dagli assets
import 'package:path_provider/path_provider.dart'; // Per trovare la cartella documenti
import '../models/data_models.dart'; // Assicurati che il percorso al tuo modello sia corretto

class MusicService {
  // Nome del file che cercheremo nella memoria del telefono
  static const String _localFileName = 'music_data.json';

  /// Recupera la lista delle playlist.
  /// Priorità:
  /// 1. Cerca nella memoria locale (se l'utente ha fatto l'importazione da zip).
  /// 2. Se non trova nulla, cerca negli assets (se hai messo dei dati di default nell'app).
  /// 3. Se non trova nulla, restituisce una lista vuota.
  Future<List<Playlist>> getPlaylists() async {
    try {
      String jsonString = '';
      bool loadedFromLocal = false;

      // 1. Ottieni il percorso della cartella documenti dell'app
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/$_localFileName');

      // 2. Controlla se il file esiste localmente (creato dal tuo import service)
      if (await localFile.exists()) {
        print("📂 MusicService: Trovato file locale aggiornato dall'utente.");
        jsonString = await localFile.readAsString();
        loadedFromLocal = true;
      } 
      
      // 3. Se non c'è il file locale, proviamo a caricare dagli assets (Backup)
      if (!loadedFromLocal) {
        print("📂 MusicService: Nessun file locale. Tento caricamento da assets...");
        try {
          jsonString = await rootBundle.loadString('assets/music_data.json');
        } catch (e) {
          print("⚠️ MusicService: Nessun file trovato nemmeno negli assets.");
          return []; // Nessun dato da mostrare
        }
      }

      if (jsonString.isEmpty) return [];

      // 4. Decodifica e conversione
      final List<dynamic> data = json.decode(jsonString);
      
      // Mappiamo il JSON nei tuoi oggetti Playlist definiti in data_models.dart
      List<Playlist> playlists = data.map((jsonItem) => Playlist.fromJson(jsonItem)).toList();
      
      print("✅ MusicService: Caricate ${playlists.length} playlist.");
      return playlists;

    } catch (e) {
      print("❌ Errore critico in MusicService: $e");
      return []; // In caso di errore, non crashare l'app, mostra vuoto.
    }
  }
}