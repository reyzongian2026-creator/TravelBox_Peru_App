#!/usr/bin/env python3
"""Analyze Flutter translations for missing/mixed keys"""

import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"

def analyze_translations():
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all 'key': 'value' patterns
    kv_pattern = r"'([a-z_]+)':\s*'([^']+)'"
    all_keys = set()
    key_values = defaultdict(list)
    
    for match in re.finditer(kv_pattern, content):
        key = match.group(1)
        value = match.group(2)
        all_keys.add(key)
        key_values[key].append(value)
    
    print(f"=" * 60)
    print(f"ANALISIS DE TRADUCCIONES")
    print(f"=" * 60)
    print(f"Total unique keys: {len(all_keys)}")
    print(f"Total key-value pairs: {sum(len(v) for v in key_values.values())}")
    
    # Find keys with multiple different values
    mixed_keys = {}
    for key, values in key_values.items():
        unique_values = set(values)
        if len(unique_values) > 1:
            mixed_keys[key] = list(unique_values)
    
    print(f"\nKeys con valores mixtos (posible corrupcion): {len(mixed_keys)}")
    
    # Check for language contamination
    # German words that shouldn't appear in other languages
    german_words = ['Anmelden', 'Abmelden', 'Konto', 'Passwort', 'Sprache', 'Lager', 'Lieferung', 
                   'Benachrichtigungen', 'Reservierungen', 'Abgeschlossen', 'Gepäck']
    
    # Italian words that shouldn't appear in other languages  
    italian_words = ['Accedi', 'Disconnetti', 'Prenota', 'Lingua', 'Magazzini', 'Consegna',
                    'Notifiche', 'Prenotazioni', 'Terminato']
    
    # French words that shouldn't appear in other languages
    french_words = ['Connexion', 'Deconnecter', 'Reserver', 'Langue', 'Entrepots', 'Livraison',
                    'Notifications', 'Reservations', 'Termine']
    
    contamination = {}
    
    for key, values in key_values.items():
        for value in values:
            for germ_word in german_words:
                if germ_word in value:
                    if key not in contamination:
                        contamination[key] = {'type': 'german', 'values': []}
                    if value not in contamination[key]['values']:
                        contamination[key]['values'].append(value)
            
            for it_word in italian_words:
                if it_word in value:
                    if key not in contamination:
                        contamination[key] = {'type': 'italian', 'values': []}
                    if value not in contamination[key]['values']:
                        contamination[key]['values'].append(value)
            
            for fr_word in french_words:
                if fr_word in value:
                    if key not in contamination:
                        contamination[key] = {'type': 'french', 'values': []}
                    if value not in contamination[key]['values']:
                        contamination[key]['values'].append(value)
    
    print(f"\nKeys contaminadas (texto en idioma wrong): {len(contamination)}")
    
    # Show sample of contaminated keys
    if contamination:
        print(f"\n--- Muestra de keys contaminadas ---")
        for i, (key, info) in enumerate(list(contamination.items())[:15]):
            print(f"  [{info['type'].upper()}] {key}: {info['values'][0][:60]}...")
    
    # Find keys that look like they have correct translations
    single_value_keys = {k: v[0] for k, v in key_values.items() if len(v) == 1}
    print(f"\nKeys con valor unico (probablemente correctas): {len(single_value_keys)}")
    
    # Save analysis results
    analysis = {
        'total_keys': len(all_keys),
        'mixed_keys_count': len(mixed_keys),
        'contamination_count': len(contamination),
        'single_value_keys_count': len(single_value_keys),
        'mixed_keys': mixed_keys,
        'contamination': contamination,
        'all_keys': sorted(list(all_keys)),
    }
    
    with open(r'C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\tools\webscraper\output\translation_analysis.json', 'w', encoding='utf-8') as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)
    
    print(f"\n[OK] Analisis guardado en translation_analysis.json")
    
    return analysis

if __name__ == '__main__':
    analyze_translations()
