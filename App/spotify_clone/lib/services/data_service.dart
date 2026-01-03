import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/data_models.dart';

class DataService {
  static const String _fileName = 'my_music_data.json';

  Future<List<Playlist>> loadPlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      String jsonString;

      if (await file.exists()) {
        jsonString = await file.readAsString();
      } else {
        // Fallback: se non c'è file salvato, usa quello di default negli assets
        jsonString = await rootBundle.loadString('assets/music_data.json');
      }

      final data = json.decode(jsonString) as List;
      return data.map((e) => Playlist.fromJson(e)).toList();
    } catch (e) {
      print("Errore DataService: $e");
      return [];
    }
  }

  Future<void> savePlaylistsFromJson(String jsonContent) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    await file.writeAsString(jsonContent);
  }
}