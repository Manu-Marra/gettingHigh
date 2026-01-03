import csv
import json
import os
import glob

# Configurazione
CSV_FOLDER = '/home/eunam/Desktop/gettingHigh/my_csv_playlists'
OUTPUT_FILE = 'music_data.json'

def main():
    all_playlists = []
    
    # Cerca tutti i file .csv nella cartella
    csv_files = glob.glob(os.path.join(CSV_FOLDER, "*.csv"))
    
    if not csv_files:
        print(f"Errore: Nessun file .csv trovato in '{CSV_FOLDER}'")
        return

    print(f"Trovate {len(csv_files)} playlist. Inizio conversione...")

    for csv_path in csv_files:
        playlist_name = os.path.splitext(os.path.basename(csv_path))[0]
        
        playlist_obj = {
            "id": playlist_name, # Usiamo il nome come ID temporaneo
            "name": playlist_name,
            "image": "", # I CSV di Exportify non hanno l'immagine, useremo un placeholder nell'app
            "tracks": []
        }
        
        try:
            with open(csv_path, mode='r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    # Exportify usa queste colonne: 'Track Name', 'Artist Name(s)', 'Album Name'
                    track_name = row.get('Track Name', '')
                    artist_name = row.get('Artist Name(s)', '')
                    album_name = row.get('Album Name', '')
                    
                    if track_name and artist_name:
                        track_obj = {
                            "name": track_name,
                            "artist": artist_name,
                            "album": album_name,
                            # Query ottimizzata per YouTube
                            "search_query": f"{track_name} {artist_name} audio" 
                        }
                        playlist_obj["tracks"].append(track_obj)
            
            # Aggiungi solo se la playlist ha canzoni
            if playlist_obj["tracks"]:
                all_playlists.append(playlist_obj)
                print(f"✔ Convertita: {playlist_name} ({len(playlist_obj['tracks'])} tracce)")
                
        except Exception as e:
            print(f"❌ Errore su {playlist_name}: {e}")

    # Salvataggio JSON finale
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(all_playlists, f, ensure_ascii=False, indent=4)
        
    print(f"\n✅ Fatto! Copia il file '{OUTPUT_FILE}' nella cartella assets della tua app Flutter.")

if __name__ == "__main__":
    main()