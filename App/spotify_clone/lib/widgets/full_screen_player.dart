import 'package:marquee/marquee.dart';
import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import '../models/data_models.dart';

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = AudioManager();
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.92, 
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),

          Expanded(
            child: AnimatedBuilder(
              animation: manager,
              builder: (context, child) {
                final track = manager.currentTrack;
                if (track == null) return const SizedBox();

                IconData loopIcon;
                Color loopColor;
                if (manager.loopMode == LoopModeState.off) {
                  loopIcon = Icons.repeat;
                  loopColor = Colors.grey;
                } else if (manager.loopMode == LoopModeState.all) {
                  loopIcon = Icons.repeat;
                  loopColor = Colors.green;
                } else {
                  loopIcon = Icons.repeat_one;
                  loopColor = Colors.green;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30), onPressed: () => Navigator.pop(context)),
                          Text("IN RIPRODUZIONE", style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey[400])),
                          const IconButton(icon: Icon(Icons.more_vert), onPressed: null),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.runtimeThumbnail != null
                          ? Image.network(track.runtimeThumbnail!, fit: BoxFit.cover, width: double.infinity, height: 350)
                          : Container(color: Colors.grey[900], height: 350, width: double.infinity, child: const Icon(Icons.music_note, size: 100)),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- CORREZIONE QUI ---
                            // Ho rimosso "Text(...)" e lasciato solo SizedBox > Marquee
                            SizedBox(
                              height: 35, // Altezza fissa per il titolo
                              child: Marquee(
                                text: track.name,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                blankSpace: 50.0,
                                velocity: 30.0,
                                pauseAfterRound: const Duration(seconds: 3),
                                startPadding: 0.0,
                                accelerationDuration: const Duration(seconds: 1),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(milliseconds: 500),
                                decelerationCurve: Curves.easeOut,
                              ),
                            ),
                            
                            const SizedBox(height: 4),

                            Text(
                              track.artist, 
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                              maxLines: 1, // Assicuriamo che l'artista non rompa il layout
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<Duration>(
                      stream: manager.positionStream,
                      builder: (context, snapPos) {
                        final pos = snapPos.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: manager.durationStream,
                          builder: (context, snapDur) {
                            final dur = snapDur.data ?? Duration.zero;
                            final max = dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0;
                            final val = pos.inSeconds.toDouble().clamp(0.0, max);
                            
                            return Column(
                              children: [
                                Slider(
                                  value: val, min: 0.0, max: max,
                                  onChanged: (v) => manager.seek(Duration(seconds: v.toInt())),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_format(pos), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(_format(dur), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                )
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(loopIcon, color: loopColor),
                            onPressed: manager.toggleLoopMode,
                          ),
                          IconButton(icon: const Icon(Icons.skip_previous, size: 45), onPressed: manager.previous),
                          Container(
                            width: 70, height: 70,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: IconButton(
                              icon: manager.isLoading 
                                 ? const CircularProgressIndicator(color: Colors.black)
                                 : Icon(manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 40, color: Colors.black),
                              onPressed: manager.togglePlayPause,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.skip_next, size: 45), onPressed: manager.next),
                          const IconButton(icon: Icon(Icons.shuffle, color: Colors.grey), onPressed: null),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}