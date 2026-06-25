@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0watch-smash-clips.ps1" -RawPath "D:\Garbage SS2" -QueuePath "%~dp0SmashClipQueue" -AutoUploadYouTube
