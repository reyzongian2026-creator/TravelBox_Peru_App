@echo off
set SCRIPT_DIR=%~dp0
powershell -ExecutionPolicy Bypass -NoExit -File "%SCRIPT_DIR%run_android_emulator.ps1"
