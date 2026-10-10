@echo off
title Cop Adam - Godot Editor
cd /d "%~dp0"
if exist "C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe" (
    start "" "C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe" -e --path "%~dp0"
) else (
    echo Godot bulunamadi! Lutfen Godot dosya yolunu kontrol edin.
    pause
)
