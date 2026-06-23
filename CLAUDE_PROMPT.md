I need help improving this local automation project for a short-form clip pipeline.

Current setup:
- We play modded Super Smash Bros. Ultimate on Nintendo Switch.
- Video comes through an Elgato Game Capture HD60 Pro into OBS Studio.
- OBS Replay Buffer is working.
- Hotkey to save replay clips: Insert.
- OBS is configured for 1080p/60 FPS recording.
- OBS currently saves replay clips to `D:\Garbage SS2`.

Goal:
When OBS saves a clip, the system should automatically:
1. Detect the new saved clip.
2. Create an upload/review package for the clip.
3. Prepare metadata for TikTok, Instagram Reels, and YouTube Shorts.
4. Eventually convert/crop clips into vertical 9:16 format.
5. Generate platform-specific captions, titles, descriptions, and hashtags.
6. Leave us with a clean review queue so the next morning we can approve/upload with minimal effort.

Important preference:
Do not build full auto-publishing yet. Build automation up to the point of a ready-to-upload package. Manual final approval/upload is fine.

Existing files:
- `watch-smash-clips.ps1`: watches the OBS output folder and creates packages.
- `start-watcher.bat`: starts the watcher.
- `README.md`: current workflow notes.

Brand/content context:
- The channel is about very skilled Smash players playing modded Smash.
- The appeal is ridiculous tech, cursed mod interactions, wild kills, weird hitboxes, disrespectful reads, and things that look illegal but are funny/hype.
- Tone should be casual, funny, hype, and player-aware.
- Do not sound corporate.
- Avoid excessive emojis.
- Do not invent exact player names, character names, stage names, or outcomes unless provided.
- We plan to use a studio mic with minimal commentary.

Platforms:
- TikTok
- Instagram Reels
- YouTube Shorts

Please help improve the pipeline step by step. Keep the game-night workflow low friction. Prefer reliable, boring automation before clever automation.
