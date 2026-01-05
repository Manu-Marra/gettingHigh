import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_manager.dart';
import 'full_screen_player.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioManager(),
      builder: (context, child) {
        final manager = AudioManager();
        final track = manager.currentTrack;

        if (track == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FullScreenPlayer(),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFF282828),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: track.runtimeThumbnail != null 
                              ? Image.network(track.runtimeThumbnail!, width: 45, height: 45, fit: BoxFit.cover)
                              : Container(color: Colors.grey[800], width: 45, height: 45, child: const Icon(Icons.music_note)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(track.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text(track.artist, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.skip_previous), onPressed: manager.previous),
                          IconButton(
                            icon: manager.isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                            onPressed: manager.togglePlayPause,
                          ),
                          IconButton(icon: const Icon(Icons.skip_next), onPressed: manager.next),
                        ],
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: manager.positionStream,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: manager.durationStream,
                          builder: (context, snapDur) {
                             final dur = snapDur.data?.inSeconds.toDouble() ?? 1.0;
                             return LinearProgressIndicator(
                               value: (pos.inSeconds.toDouble() / (dur > 0 ? dur : 1.0)).clamp(0.0, 1.0),
                               backgroundColor: Colors.transparent,
                               valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                               minHeight: 2.0,
                             );
                          }
                        );
                      }
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
