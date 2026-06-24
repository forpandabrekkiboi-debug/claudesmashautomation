"""
Upload a clip package to YouTube as a private video.

Usage:
    python upload_youtube.py <package_folder>

Example:
    python upload_youtube.py SmashClipQueue\2026-06-24_01-23-45_clip
"""

import argparse
import json
import os
import sys

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
CLIENT_SECRET = os.path.join(os.path.dirname(__file__), "client_secret.json")
TOKEN_FILE = os.path.join(os.path.dirname(__file__), "token.json")
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov", ".flv"}


def get_credentials():
    creds = None
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(TOKEN_FILE, "w") as f:
            f.write(creds.to_json())
    return creds


def find_video(package_dir):
    for f in os.listdir(package_dir):
        name, ext = os.path.splitext(f)
        if name == "clip_original" and ext.lower() in VIDEO_EXTENSIONS:
            return os.path.join(package_dir, f)
    return None


def read_platform_file(package_dir, filename):
    path = os.path.join(package_dir, filename)
    if not os.path.exists(path):
        return {}
    data = {}
    current_key = None
    lines = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.endswith(":") and not line.startswith(" "):
                if current_key and lines:
                    data[current_key] = "\n".join(lines).strip()
                current_key = line[:-1].lower()
                lines = []
            else:
                lines.append(line)
    if current_key and lines:
        data[current_key] = "\n".join(lines).strip()
    return data


def main():
    parser = argparse.ArgumentParser(description="Upload a clip package to YouTube as private.")
    parser.add_argument("package", help="Path to the clip package folder")
    args = parser.parse_args()

    package_dir = os.path.abspath(args.package)
    if not os.path.isdir(package_dir):
        print(f"ERROR: Not a directory: {package_dir}")
        sys.exit(1)

    video_path = find_video(package_dir)
    if not video_path:
        print("ERROR: No clip_original video found in package.")
        sys.exit(1)

    yt_data = read_platform_file(package_dir, "youtube_shorts.txt")
    title = yt_data.get("title", "").strip() or os.path.basename(package_dir)
    description = yt_data.get("description", "").strip()
    hashtags = yt_data.get("hashtags", "").strip()
    if hashtags:
        description = f"{description}\n\n{hashtags}".strip()

    status = yt_data.get("status", "").strip().lower()
    if status and status != "needs review":
        print(f"Package status is '{status}' — already uploaded or skipped?")
        answer = input("Upload anyway? [y/N] ").strip().lower()
        if answer != "y":
            sys.exit(0)

    print(f"Package : {package_dir}")
    print(f"Video   : {video_path}")
    print(f"Title   : {title}")
    print(f"Desc    : {description[:80]}{'...' if len(description) > 80 else ''}")
    print()

    creds = get_credentials()
    youtube = build("youtube", "v3", credentials=creds)

    body = {
        "snippet": {
            "title": title,
            "description": description,
            "categoryId": "20",  # Gaming
        },
        "status": {
            "privacyStatus": "private",
            "selfDeclaredMadeForKids": False,
        },
    }

    media = MediaFileUpload(video_path, chunksize=4 * 1024 * 1024, resumable=True)
    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)

    print("Uploading...")
    response = None
    while response is None:
        status_obj, response = request.next_chunk()
        if status_obj:
            pct = int(status_obj.resumable_progress / status_obj.total_size * 100)
            print(f"  {pct}%", end="\r")

    video_id = response["id"]
    video_url = f"https://youtu.be/{video_id}"
    print(f"\nDone: {video_url}")

    metadata_path = os.path.join(package_dir, "metadata.json")
    if os.path.exists(metadata_path):
        with open(metadata_path, encoding="utf-8-sig") as f:
            metadata = json.load(f)
        metadata["youtube_video_id"] = video_id
        metadata["youtube_url"] = video_url
        with open(metadata_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)

    yt_file = os.path.join(package_dir, "youtube_shorts.txt")
    if os.path.exists(yt_file):
        with open(yt_file, encoding="utf-8") as f:
            content = f.read()
        content = content.replace("Needs review", f"Uploaded (private)\n{video_url}")
        with open(yt_file, "w", encoding="utf-8") as f:
            f.write(content)

    print("metadata.json and youtube_shorts.txt updated.")


if __name__ == "__main__":
    main()
