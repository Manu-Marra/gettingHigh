import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class PlaylistImportService {
  
  // Nome del file finale dove salveremo i dati sul telefono
  static const String outputFileName = 'music_data.json';

  /// Funzione principale: apre il picker, processa lo zip e salva il json
  Future<bool> importPlaylistsFromZip() async {
    try {
      // 1. Chiedi all'utente di selezionare il file ZIP scaricato da Exportify
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return false; // Utente ha annullato

      File zipFile = File(result.files.single.path!);
      
      // 2. Leggi i bytes dello zip
      final bytes = await zipFile.readAsBytes();
      
      // 3. Decomprimi l'archivio (sostituisce zipfile di Python)
      final archive = ZipDecoder().decodeBytes(bytes);

      List<Map<String, dynamic>> allPlaylists = [];

      // 4. Itera sui file dentro lo zip
      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase().endsWith(".csv")) {
          // È un CSV! Processiamolo.
          String playlistName = file.name.replaceAll('.csv', '');
          
          // Estrai il contenuto del CSV in stringa
          final content = utf8.decode(file.content as List<int>);
          
          // Parsing CSV (sostituisce csv.DictReader di Python)
          // La libreria csv di dart restituisce una List<List<dynamic>>
          List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(content);

          if (rows.isEmpty) continue;

          // Cerchiamo gli indici delle colonne (Exportify può variare, ma di solito sono fisse)
          // Exportify header: Track Name, Artist Name(s), Album Name
          List<dynamic> headers = rows.first;
          int nameIndex = headers.indexOf('Track Name');
          int artistIndex = headers.indexOf('Artist Name(s)');
          int albumIndex = headers.indexOf('Album Name');

          // Se le colonne non ci sono, saltiamo
          if (nameIndex == -1 || artistIndex == -1) continue;

          List<Map<String, dynamic>> tracks = [];

          // Saltiamo la riga 0 (header) e leggiamo i dati
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            // Controllo sicurezza lunghezza riga
            if (row.length <= artistIndex) continue;

            String trackName = row[nameIndex].toString();
            String artistName = row[artistIndex].toString();
            String albumName = (albumIndex != -1 && row.length > albumIndex) 
                ? row[albumIndex].toString() 
                : '';

            if (trackName.isNotEmpty && artistName.isNotEmpty) {
              tracks.add({
                "name": trackName,
                "artist": artistName,
                "album": albumName,
                "search_query": "$trackName $artistName audio"
              });
            }
          }

          if (tracks.isNotEmpty) {
            allPlaylists.add({
              "id": playlistName,
              "name": playlistName,
              "image": "", // Placeholder
              "tracks": tracks
            });
          }
        }
      }

      // 5. Salvataggio del JSON finale nella memoria del telefono
      await _saveJsonToDevice(allPlaylists);
      return true;

    } catch (e) {
      print("Errore durante l'importazione: $e");
      return false;
    }
  }

  Future<void> _saveJsonToDevice(List<Map<String, dynamic>> playlists) async {
    // Otteniamo la cartella documenti dell'app (dove possiamo scrivere)
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$outputFileName');
    
    // Scriviamo il file come stringa JSON
    String jsonString = json.encode(playlists);
    await file.writeAsString(jsonString);
    print("✅ Salvato music_data.json in: ${file.path}");
  }
}