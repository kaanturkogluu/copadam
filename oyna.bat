@echo off
title Cop Adam - Baslat
cd /d "%~dp0"
set GODOT=C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe

if exist "%GODOT%" (
    echo Cop Adam oyunu baslatiliyor...
    start "" "%GODOT%" --path "%~dp0"
) else (
    echo [HATA] Godot dosyasi bulunamadi: %GODOT%
    pause
)
