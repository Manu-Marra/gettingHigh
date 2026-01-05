import csv
import json
import os
import glob
import shutil

# --- CONFIGURAZIONE PERCORSI ---

# 1. Cartella da cui prelevare i file appena scaricati (Downloads di sistema)
DOWNLOADS_SYSTEM_FOLDER = '/home/eunam/Downloads'

# 2. Cartella dove archiviare i CSV del progetto
PROJECT_CSV_FOLDER = '/home/eunam/Desktop/gettingHigh/my_csv_playlists'

# 3. Cartella di destinazione per il JSON (Assets dell'App Flutter)
# Calcolo dinamico basato sulla posizione di questo script
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
ASSETS_FOLDER = os.path.join(BASE_DIR, 'spotify_clone', 'assets')
OUTPUT_FILE_NAME = 'music_data.json'
OUTPUT_PATH = os.path.join(ASSETS_FOLDER, OUTPUT_FILE_NAME)


def move_csv_from_downloads():
    """
    Cerca file .csv nella cartella Downloads e li sposta nella cartella del progetto.
    """
    print(f"🔍 Controllo nuovi CSV in: {DOWNLOADS_SYSTEM_FOLDER}...")
    
    # Cerca tutti i csv in Downloads
    downloaded_csvs = glob.glob(os.path.join(DOWNLOADS_SYSTEM_FOLDER, "*.csv"))
    
    count_moved = 0
    
    if not os.path.exists(PROJECT_CSV_FOLDER):
        os.makedirs(PROJECT_CSV_FOLDER)

    for csv_file in downloaded_csvs:
        filename = os.path.basename(csv_file)
        destination = os.path.join(PROJECT_CSV_FOLDER, filename)
        
        # Opzionale: Filtro per evitare di spostare CSV che non c'entrano nulla
        # Exportify di solito crea file tipo "nome_playlist.csv" o "playlist.csv"
        # Se vuoi spostare TUTTI i csv, lascia così.
        
        try:
            shutil.move(csv_file, destination)
            print(f"   🚚 Spostato: {filename}")
            count_moved += 1
        except Exception as e:
            print(f"   ⚠️ Errore spostamento {filename}: {e}")
            
    if count_moved > 0:
        print(f"✅ Spostati {count_moved} file in '{PROJECT_CSV_FOLDER}'\n")
    else:
        print("ℹ️ Nessun nuovo file .csv trovato nei Downloads.\n")


def convert_csv_to_json():
    all_playlists = []
    
    # Verifica cartella assets
    if not os.path.exists(ASSETS_FOLDER):
        print(f"⚠️ Creazione cartella assets mancante: {ASSETS_FOLDER}")
        os.makedirs(ASSETS_FOLDER)

    # Cerca i file nella cartella del progetto (dove li abbiamo appena spostati o dove erano già)
    csv_files = glob.glob(os.path.join(PROJECT_CSV_FOLDER, "*.csv"))
    
    if not csv_files:
        print(f"Errore: Nessun file .csv trovato in '{PROJECT_CSV_FOLDER}'")
        return

    print(f"🎵 Inizio conversione di {len(csv_files)} playlist...")

    for csv_path in csv_files:
        playlist_name = os.path.splitext(os.path.basename(csv_path))[0]
        
        playlist_obj = {
            "id": playlist_name,
            "name": playlist_name,
            "image": "", 
            "tracks": []
        }
        
        try:
            with open(csv_path, mode='r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    track_name = row.get('Track Name', '')
                    artist_name = row.get('Artist Name(s)', '')
                    album_name = row.get('Album Name', '')
                    
                    if track_name and artist_name:
                        track_obj = {
                            "name": track_name,
                            "artist": artist_name,
                            "album": album_name,
                            "search_query": f"{track_name} {artist_name} audio" 
                        }
                        playlist_obj["tracks"].append(track_obj)
            
            if playlist_obj["tracks"]:
                all_playlists.append(playlist_obj)
                print(f"   ✔ Convertita: {playlist_name} ({len(playlist_obj['tracks'])} brani)")
                
        except Exception as e:
            print(f"   ❌ Errore su {playlist_name}: {e}")

    # Salvataggio JSON
    try:
        with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
            json.dump(all_playlists, f, ensure_ascii=False, indent=4)
        print(f"\n✅ Fatto! JSON aggiornato in: {OUTPUT_PATH}")
    except Exception as e:
        print(f"\n❌ Errore salvataggio JSON: {e}")

def main():
    # 1. Prima sposta i file scaricati
    move_csv_from_downloads()
    # 2. Poi converte tutto quello che c'è nella cartella del progetto
    convert_csv_to_json()

if __name__ == "__main__":
    main()