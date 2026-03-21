@echo off
cd /d C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App
echo === Git Status ===
git status
echo.
echo === Git Add ===
git add .
echo.
echo === Git Commit ===
git commit -m "feat: add 18 new i18n keys for admin forms and checkout - Added warehouse_deactivation_confirmation, warehouse_name_label, address_label - Added capacity_label, opening_time_label, closing_time_label - Added nationality_label, document_number_label, vehicle_plate_label - Added valid_phone_label, valid_emergency_phone_label, current_password_label - Added price_suffix_per_reservation, price_suffix_per_order - Added start_date_label, end_date_label, hours_unit, packages_unit - All 18 keys translated in 6 languages: es, en, de, fr, it, pt - Replaced hardcoded Spanish strings in 4 feature files Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
echo.
echo === Git Log ===
git log --oneline -3
echo.
echo === Git Push ===
git push origin main
