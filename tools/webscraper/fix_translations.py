#!/usr/bin/env python3
"""
Fix corrupted Flutter translations - v2
"""
import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"

# Language detection patterns
LANG_PATTERNS = {
    'es': ['Reserva', 'Almacen', ' Peru', ' Peru', 'Usuario', 'Cliente', 'Iniciar', 'Cerrar',
           'Cobro', 'Incidencia', 'Operador', 'Admin', 'Confirmar', 'Cancelar', 'Error', 'Exito',
           'Pendiente', 'Completado', 'Crear', 'Editar', 'Eliminar', 'Guardar', 'Buscar'],
    'en': ['Reserve', 'Warehouse', 'Login', 'Sign', 'Welcome', 'Search', 'Client', 'User',
           'Password', 'Email', 'Phone', 'Name', 'Address', 'Time', 'Date', 'Price', 'Total'],
    'de': ['Anmelden', 'Abmelden', 'Konto', 'Passwort', 'Sprache', 'Lager', 'Lieferung',
           'Benachrichtigungen', 'Reservierungen', 'Abgeschlossen', 'Gepaeck', 'Kunden'],
    'fr': ['Connexion', 'Deconnecter', 'Compte', 'Langue', 'Entrepots', 'Livraison',
           'Notifications', 'Reservations', 'Termine', 'Bagages', 'Client', 'Utilisateur'],
    'it': ['Accedi', 'Disconnetti', 'Account', 'Password', 'Lingua', 'Magazzini', 'Consegna',
           'Notifiche', 'Prenotazioni', 'Terminato', 'Bagagli', 'Cliente', 'Utente'],
    'pt': ['Entrar', 'Sair', 'Conta', 'Senha', 'Idioma', 'Armazens', 'Entrega',
           'Notificacoes', 'Reservas', 'Concluido', 'Bagagem', 'Cliente', 'Usuario']
}

def detect_lang(text):
    text_l = text.lower()
    scores = {lang: 0 for lang in LANG_PATTERNS}
    for lang, patterns in LANG_PATTERNS.items():
        for p in patterns:
            if p.lower() in text_l:
                scores[lang] += 1
    if max(scores.values()) > 0:
        return max(scores, key=scores.get)
    return 'es'  # Default

def extract_block(content, start_pattern):
    """Extract a translation block from content"""
    match = re.search(start_pattern, content)
    if not match:
        return None, 0, 0
    
    start = match.start()
    # Find the opening brace
    brace_start = content.find('{', start)
    
    # Count braces to find matching close
    count = 0
    for i in range(brace_start, len(content)):
        if content[i] == '{':
            count += 1
        elif content[i] == '}':
            count -= 1
            if count == 0:
                return content[brace_start:i+1], brace_start, i+1
    return None, 0, 0

def parse_translations(block):
    """Parse key-value pairs from a translation block"""
    translations = {}
    kv_pattern = r"'([a-z_]+)':\s*'([^']*)'"
    
    # First extract language blocks
    lang_pattern = r"'([a-z]{2})':\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}"
    
    for lang_match in re.finditer(lang_pattern, block, re.DOTALL):
        lang = lang_match.group(1)
        lang_block = lang_match.group(2)
        
        # Extract key-value pairs from this language block
        for kv_match in re.finditer(kv_pattern, lang_block):
            key = kv_match.group(1)
            value = kv_match.group(2)
            if lang not in translations:
                translations[lang] = {}
            translations[lang][key] = value
    
    return translations

def fix_translations():
    print("=" * 60)
    print("REPARACION DE TRADUCCIONES DE FLUTTER")
    print("=" * 60)
    
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract all 3 translation maps
    blocks = [
        ('_runtimeOverrides', r"static final Map<String, Map<String, String>> _runtimeOverrides = \{"),
        ('_priorityTranslations', r"static const Map<String, Map<String, String>> _priorityTranslations = \{"),
        ('_translations', r"static const Map<String, Map<String, String>> _translations = \{"),
    ]
    
    all_translations = {}
    all_corrupted = []
    
    for name, pattern in blocks:
        print(f"\n[*] Analizando {name}...")
        block, start, end = extract_block(content, pattern)
        if block:
            trans = parse_translations(block)
            all_translations[name] = trans
            
            total_keys = sum(len(t) for t in trans.values())
            print(f"    Encontradas {total_keys} traducciones en {len(trans)} idiomas")
            
            # Check for corrupted
            corrupted_in_block = 0
            for lang, kvs in trans.items():
                for key, value in kvs.items():
                    detected = detect_lang(value)
                    if detected != lang:
                        corrupted_in_block += 1
                        all_corrupted.append({
                            'block': name,
                            'key': key,
                            'stored_as': lang,
                            'detected_as': detected,
                            'value': value[:100]
                        })
            
            if corrupted_in_block > 0:
                print(f"    [!] {corrupted_in_block} traducciones corrup tas detectadas")
        else:
            print(f"    [!] No se encontro el bloque")
            all_translations[name] = {}
    
    # Summary
    print(f"\n{'=' * 60}")
    print(f"RESUMEN")
    print(f"{'=' * 60}")
    
    total_keys = sum(len(t) for t in all_translations['_translations'].values())
    print(f"Total keys en _translations: {total_keys}")
    print(f"Total corrupciones encontradas: {len(all_corrupted)}")
    
    # Save corruption report
    report = {
        'total_corrupted': len(all_corrupted),
        'corrupted': all_corrupted
    }
    with open(r'C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\tools\webscraper\output\corruption_report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\n[OK] Reporte guardado en corruption_report.json")
    
    # Show sample
    if all_corrupted:
        print(f"\n--- Muestra de corrupcion ---")
        for item in all_corrupted[:30]:
            print(f"  [{item['stored_as']}<-{item['detected_as']}] {item['key']}")
            print(f"      = {item['value']}")
    
    return all_translations, all_corrupted

if __name__ == '__main__':
    fix_translations()
