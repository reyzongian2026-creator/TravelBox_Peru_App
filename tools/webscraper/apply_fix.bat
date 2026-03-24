@echo off
REM ============================================================================
REM Translation Fix Deployment Script
REM ============================================================================

echo ============================================================
echo   TravelBox Peru - Translation Fix Deployment
echo ============================================================
echo.

cd /d "%~dp0..\.."

REM Check if fixed file exists
if not exist "lib\core\l10n\app_localizations_fixed.dart" (
    echo ERROR: Fixed file not found!
    echo Run smart_fix.py first.
    pause
    exit /b 1
)

REM Create backup of original
echo [*] Creating backup of original file...
copy "lib\core\l10n\app_localizations.dart" "lib\core\l10n\app_localizations_backup_pre_fix.dart"
if %errorlevel% neq 0 (
    echo ERROR: Failed to create backup!
    pause
    exit /b 1
)
echo [OK] Backup created: app_localizations_backup_pre_fix.dart

REM Replace original with fixed
echo [*] Replacing original file with fixed version...
copy "lib\core\l10n\app_localizations_fixed.dart" "lib\core\l10n\app_localizations.dart" /y
if %errorlevel% neq 0 (
    echo ERROR: Failed to replace file!
    pause
    exit /b 1
)
echo [OK] File replaced

REM Clean Flutter cache
echo.
echo [*] Cleaning Flutter cache...
flutter clean > nul 2>&1
flutter pub get > nul 2>&1
echo [OK] Cache cleaned

echo.
echo ============================================================
echo   FIX APPLIED SUCCESSFULLY!
echo ============================================================
echo.
echo Files:
echo   - Original: app_localizations_backup_pre_fix.dart
echo   - Fixed:    app_localizations.dart
echo.
echo Next steps:
echo   1. flutter build web
echo   2. Deploy to production
echo.
echo NOTE: Some translations may still need manual review.
echo       Check tools\webscraper\output for analysis reports.
echo.
pause
