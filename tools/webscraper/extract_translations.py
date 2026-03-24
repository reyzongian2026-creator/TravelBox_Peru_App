#!/usr/bin/env python3
"""
Extract all translation keys from Flutter app_localizations.dart
"""

import re
import json
import os
from pathlib import Path

# Configuration
DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"
OUTPUT_DIR = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\tools\webscraper\output"

def extract_translations():
    """Extract all translations from Dart localization file"""
    
    print("[*] Leyendo archivo de localizaciones...")
    
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    translations = {
        'es': {},
        'en': {},
        'de': {},
        'fr': {},
        'it': {},
        'pt': {}
    }
    
    languages = ['es', 'en', 'de', 'fr', 'it', 'pt']
    
    for lang in languages:
        # Look for translations in _translations, _priorityTranslations, and _runtimeOverrides
        patterns = [
            rf"static final Map<String, Map<String, String>> _translations\s*=\s*\{{[^}}]*'{lang}':\s*\{{([^}}]*)}}",
            rf"static final Map<String, Map<String, String>> _priorityTranslations\s*=\s*{{[^}}]*'{lang}':\s*\{{([^}}]*)}}",
            rf"static final Map<String, Map<String, String>> _runtimeOverrides\s*=\s*{{[^}}]*'{lang}':\s*\{{([^}}]*)}}",
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, content, re.DOTALL)
            for match in matches:
                # Extract key-value pairs
                kv_pattern = r"'(.+?)':\s*'(.+?)'"
                kvs = re.findall(kv_pattern, match)
                for key, value in kvs:
                    translations[lang][key] = value
    
    # Also try to find any standalone translation maps
    all_translations_found = {}
    
    # Find all "'key': 'value'" patterns in the file
    all_pattern = r"'(?P<key>[a-z_]+)'\s*:\s*'(?P<value>[^']+)'"
    for match in re.finditer(all_pattern, content):
        key = match.group('key')
        value = match.group('value')
        all_translations_found[key] = value
    
    # Remove duplicates (first occurrence wins)
    translations_by_lang = {}
    for lang in languages:
        lang_translations = {}
        for key, value in all_translations_found.items():
            # Check if this key appears in the language section
            # This is a simplified approach
            lang_translations[key] = value
        translations_by_lang[lang] = lang_translations
    
    return translations, all_translations_found

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    translations, all_found = extract_translations()
    
    # Save JSON
    output_json = os.path.join(OUTPUT_DIR, "translation_keys.json")
    with open(output_json, 'w', encoding='utf-8') as f:
        json.dump({
            'total_unique_keys': len(all_found),
            'translations': all_found
        }, f, indent=2, ensure_ascii=False)
    
    print(f"[OK] Keys extraidas: {len(all_found)}")
    print(f"[OK] Guardado en: {output_json}")
    
    # Save as text list
    output_txt = os.path.join(OUTPUT_DIR, "translation_keys.txt")
    with open(output_txt, 'w', encoding='utf-8') as f:
        f.write("TravelBox Peru - Translation Keys\n")
        f.write("=" * 50 + "\n\n")
        
        sorted_keys = sorted(all_found.keys())
        for key in sorted_keys:
            value = all_found[key]
            f.write(f"{key}: {value}\n")
    
    print(f"[OK] Guardado en: {output_txt}")
    
    # Show sample
    print("\n=== Sample Keys ===")
    for i, (key, value) in enumerate(list(all_found.items())[:20]):
        print(f"  {key}: {value}")

if __name__ == '__main__':
    main()