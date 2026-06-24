param(
    [string]$RawPath = "D:\Garbage SS2",
    [string]$QueuePath = "$PSScriptRoot\SmashClipQueue",
    [switch]$ScanExisting,
    [switch]$AutoUploadYouTube
)

$ErrorActionPreference = "Stop"
$videoExtensions = @(".mp4", ".mkv", ".mov", ".flv")

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
}

function Convert-ToSafeName {
    param([string]$Name)
    $safe = [IO.Path]::GetFileNameWithoutExtension($Name)
    $safe = $safe -replace '[^\w\-. ]+', ''
    $safe = $safe.Trim() -replace '\s+', '-'
    if ([string]::IsNullOrWhiteSpace($safe)) { return "clip" }
    return $safe
}

function Wait-FileStable {
    param([string]$Path)
    $lastLength = -1
    $stableCount = 0

    for ($i = 0; $i -lt 120; $i++) {
        if (-not (Test-Path -LiteralPath $Path)) {
            Start-Sleep -Milliseconds 500
            continue
        }

        try {
            $item = Get-Item -LiteralPath $Path
            $length = $item.Length
            if ($length -eq $lastLength -and $length -gt 0) {
                $stableCount++
            } else {
                $stableCount = 0
                $lastLength = $length
            }

            if ($stableCount -ge 4) { return $true }
        } catch {
            $stableCount = 0
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function New-ClipPackage {
    param([string]$VideoPath)

    if (-not (Test-Path -LiteralPath $VideoPath)) { return }

    $item = Get-Item -LiteralPath $VideoPath
    if ($videoExtensions -notcontains $item.Extension.ToLowerInvariant()) { return }

    Write-Log "New clip detected: $($item.Name)"

    if (-not (Wait-FileStable -Path $VideoPath)) {
        Write-Log "Skipped unstable file: $VideoPath" "WARN"
        return
    }

    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $safeName = Convert-ToSafeName -Name $item.Name
    $packagePath = Join-Path $QueuePath "$stamp`_$safeName"

    if (Test-Path -LiteralPath $packagePath) { return }

    New-Item -ItemType Directory -Force -Path $packagePath | Out-Null

    $packageVideo = Join-Path $packagePath ("clip_original" + $item.Extension.ToLowerInvariant())
    try {
        New-Item -ItemType HardLink -Path $packageVideo -Target $item.FullName | Out-Null
    } catch {
        Copy-Item -LiteralPath $item.FullName -Destination $packageVideo -Force
    }

    $metadata = [ordered]@{
        source_file      = $item.FullName
        package_file     = $packageVideo
        created_at       = (Get-Date).ToString("s")
        status           = "needs_review"
        clip_note        = ""
        players          = ""
        characters       = ""
        platform_targets = @("tiktok", "instagram_reels", "youtube_shorts")
    }
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $packagePath "metadata.json") -Encoding UTF8

    @"
Clip note:

What happened:

Players:

Characters:

Stage:

Tone tags:
hype, funny, modded, disrespectful, skilled
"@ | Set-Content -LiteralPath (Join-Path $packagePath "clip_note.txt") -Encoding UTF8

    @"
Paste this into Claude after filling in clip_note.txt:

You are helping caption a short-form clip for a modded Super Smash Bros. Ultimate channel.

Use this context:
- Two very skilled Smash players are playing a modded Switch setup.
- The appeal is ridiculous tech, cursed mod interactions, wild kills, disrespectful reads, and things that look illegal but are funny/hype.
- Platforms: TikTok, Instagram Reels, YouTube Shorts.
- Tone: casual, funny, hype, player-aware.
- Do not sound corporate.
- Avoid excessive emojis.
- Do not invent exact character names, player names, or outcomes unless provided.

Clip file:
$($item.Name)

Clip note:
[paste the filled-in note here]

Produce:
1. Internal filename/title
2. TikTok caption and 8-12 hashtags
3. Instagram Reels caption and 6-10 hashtags
4. YouTube Shorts title under 70 characters, 1-2 line description, and 3-5 hashtags
5. Five alternate hooks
"@ | Set-Content -LiteralPath (Join-Path $packagePath "claude_prompt.txt") -Encoding UTF8

    @"
Title:

Caption:

Hashtags:

Status:
Needs review
"@ | Set-Content -LiteralPath (Join-Path $packagePath "tiktok.txt") -Encoding UTF8

    @"
Caption:

Hashtags:

Status:
Needs review
"@ | Set-Content -LiteralPath (Join-Path $packagePath "instagram_reels.txt") -Encoding UTF8

    @"
Title:

Description:

Hashtags:

Status:
Needs review
"@ | Set-Content -LiteralPath (Join-Path $packagePath "youtube_shorts.txt") -Encoding UTF8

    Write-Log "Packaged: $packagePath"
    return $packagePath
}

# --- Setup ---

New-Item -ItemType Directory -Force -Path $RawPath, $QueuePath | Out-Null
$script:LogFile = Join-Path $QueuePath "watcher.log"

Write-Log "Watcher starting. Raw: $RawPath | Queue: $QueuePath"

if ($ScanExisting) {
    Write-Log "Scanning existing files..."
    Get-ChildItem -LiteralPath $RawPath -File |
        Where-Object { $videoExtensions -contains $_.Extension.ToLowerInvariant() } |
        ForEach-Object { New-ClipPackage -VideoPath $_.FullName }
}

# Thread-safe queue — event handler only enqueues; main loop does all the work.
# This avoids the PowerShell event-handler scope limitation where functions and
# variables defined in the script are not visible inside the action scriptblock.
$pendingQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

$watcher = New-Object IO.FileSystemWatcher
$watcher.Path = $RawPath
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $q = $Event.MessageData
    $q.Enqueue($path)
}

Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $pendingQueue | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $pendingQueue | Out-Null

$script:UploadScript = Join-Path $PSScriptRoot "upload_youtube.py"

Write-Host ""
Write-Host "Watching: $RawPath"
Write-Host "Queue:    $QueuePath"
Write-Host "Log:      $($script:LogFile)"
if ($AutoUploadYouTube) { Write-Host "Mode:     Auto-upload to YouTube (private)" }
Write-Host "Press Ctrl+C to stop."
Write-Host ""

# Main loop — drains the pending queue and packages clips
while ($true) {
    $path = $null
    while ($pendingQueue.TryDequeue([ref]$path)) {
        try {
            $packagePath = New-ClipPackage -VideoPath $path
            if ($AutoUploadYouTube -and $packagePath -and (Test-Path -LiteralPath $script:UploadScript)) {
                Write-Log "Auto-uploading to YouTube: $packagePath"
                python $script:UploadScript $packagePath
            }
        } catch {
            Write-Log "Error processing $path`: $_" "ERROR"
        }
    }
    Start-Sleep -Seconds 2
}
