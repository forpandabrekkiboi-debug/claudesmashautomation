# Smash Clip Automation

This project packages OBS replay-buffer clips for short-form upload review.

## Current OBS Setup

- Source: Nintendo Switch through Elgato Game Capture HD60 Pro
- App: OBS Studio
- Replay hotkey: Insert
- Target recording quality: 1080p / 60 FPS
- Current OBS output folder:
  `D:\Garbage SS2`

## Goal

When OBS saves a clip, the automation should:

1. Detect the new video in `D:\Garbage SS2`.
2. Create a per-clip folder in a review queue.
3. Include the original clip.
4. Create metadata and caption files for:
   - TikTok
   - Instagram Reels
   - YouTube Shorts
5. Keep final upload manual for now.

## Style

The channel is about skilled players playing modded Super Smash Bros. Ultimate.

Tone: casual, funny, hype, player-aware.

Avoid:

- corporate captions
- excessive emojis
- invented details not provided by the clip note

## Workflow

1. Start `start-watcher.bat`.
2. Start OBS Replay Buffer.
3. Press Insert during gameplay to save clips.
4. Review generated packages in `SmashClipQueue`.

