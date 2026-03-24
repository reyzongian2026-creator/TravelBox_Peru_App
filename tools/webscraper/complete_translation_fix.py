#!/usr/bin/env python3
"""
Complete Flutter Translation Fixer - Extract, Clean, Regenerate
"""
import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"
OUTPUT_FIXED = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations_fixed.dart"
REPORT_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\tools\webscraper\output\fix_report.json"

# Language detection patterns (sorted by specificity)
LANG_PATTERNS = {
    'de': ['Anmelden', 'Abmelden', 'Konto erstellen', 'Passwort', 'Sprache', 'Lager', 'Lieferung',
           'Benachrichtigungen', 'Reservierungen', 'Abgeschlossen', 'Gepaeck', 'Kunden',
           'Benutzer', 'E-Mail', 'Telefon', 'Name', 'Adresse', 'Zeit', 'Datum',
           'Preis', 'Gesamt', 'Zahlung', 'Tasche', 'Abholung', 'Bestaetigen',
           'Abbrechen', 'Fehler', 'Erfolg', 'Ausstehend', 'Scannen', 'Code',
           'Statut', 'Verlauf', 'Einstellungen', 'Profil', 'Registrieren', 'Erstellen',
           'Startseite', 'Menue', 'Suchen', 'Filtern', 'Sortieren', 'Aktualisieren',
           'Drucken', 'Exportieren', 'Teilen', 'Kopieren', 'Ansehen', 'Details'],
    
    'fr': ['Connexion', 'Deconnecter', 'Creer un compte', 'Mot de passe', 'Langue', 'Entrepots', 'Livraison',
           'Notifications', 'Reservations', 'Termine', 'Bagages', 'Client', 'Utilisateur',
           'Email', 'Telephone', 'Nom', 'Adresse', 'Heure', 'Date', 'Prix',
           'Total', 'Paiement', 'Sac', 'Retrait', 'Confirmer', 'Annuler',
           'Erreur', 'Succes', 'En_attente', 'Scanner', 'Code',
           'Statut', 'Historique', 'Parametres', 'Profil', 'S_inscrire',
           'Accueil', 'Menu', 'Rechercher', 'Filtrer', 'Trier', 'Actualiser',
           'Imprimer', 'Exporter', 'Partager', 'Copier', 'Voir', 'Details'],
    
    'it': ['Accedi', 'Disconnetti', 'Crea account', 'Password', 'Lingua', 'Magazzini', 'Consegna',
           'Notifiche', 'Prenotazioni', 'Terminato', 'Bagagli', 'Cliente', 'Utente',
           'Email', 'Telefono', 'Nome', 'Indirizzo', 'Ora', 'Data', 'Prezzo',
           'Totale', 'Pagamento', 'Borsa', 'Ritiro', 'Conferma', 'Annulla',
           'Errore', 'Successo', 'In_attesa', 'Scansiona', 'Codice',
           'Stato', 'Cronologia', 'Impostazioni', 'Profilo', 'Registrati',
           'Home', 'Menu', 'Cerca', 'Filtra', 'Ordina', 'Aggiorna',
           'Stampa', 'Esporta', 'Condividi', 'Copia', 'Vedi', 'Dettagli'],
    
    'pt': ['Entrar', 'Sair', 'Cadastrar', 'Senha', 'Idioma', 'Armazens', 'Entrega',
           'Notificacoes', 'Reservas', 'Concluido', 'Bagagem', 'Cliente', 'Usuario',
           'Email', 'Telefone', 'Nome', 'Endereco', 'Hora', 'Data', 'Preco',
           'Total', 'Pagamento', 'Bolsa', 'Retirada', 'Confirmar', 'Cancelar',
           'Erro', 'Sucesso', 'Pendente', 'Escanear', 'Codigo',
           'Status', 'Historico', 'Configuracoes', 'Perfil', 'Cadastrar',
           'Inicio', 'Menu', 'Pesquisar', 'Filtrar', 'Ordenar', 'Atualizar',
           'Imprimir', 'Exportar', 'Compartilhar', 'Copiar', 'Ver', 'Detalhes'],
    
    'en': ['Login', 'Logout', 'Register', 'Password', 'Language', 'Warehouse', 'Delivery',
           'Notifications', 'Reservations', 'Completed', 'Bags', 'Client', 'User',
           'Email', 'Phone', 'Name', 'Address', 'Time', 'Date', 'Price',
           'Total', 'Payment', 'Bag', 'Pickup', 'Confirm', 'Cancel',
           'Error', 'Success', 'Pending', 'Scan', 'Code',
           'Status', 'History', 'Settings', 'Profile',
           'Home', 'Menu', 'Search', 'Filter', 'Sort', 'Refresh',
           'Print', 'Export', 'Share', 'Copy', 'View', 'Details',
           'Active', 'Inactive', 'Processing', 'Waiting', 'Approved', 'Rejected',
           'First Name', 'Last Name', 'Country', 'ZIP Code', 'Notes', 'Comments',
           'Summary', 'Subtotal', 'Tax', 'Discount', 'Currency',
           'Year', 'Week', 'Day', 'Month', 'Hour'],
    
    'es': ['Iniciar', 'Cerrar', 'Registrarse', 'Contrasena', 'Idioma', 'Almacen', 'Entrega',
           'Notificaciones', 'Reservas', 'Completado', 'Maletas', 'Cliente', 'Usuario',
           'Correo', 'Telefono', 'Nombre', 'Direccion', 'Hora', 'Fecha', 'Precio',
           'Total', 'Pago', 'Bulto', 'Recojo', 'Confirmar', 'Cancelar',
           'Error', 'Exito', 'Pendiente', 'Escanear', 'Codigo',
           'Estado', 'Historial', 'Configuracion', 'Perfil',
           'Inicio', 'Menu', 'Buscar', 'Filtrar', 'Ordenar', 'Actualizar',
           'Imprimir', 'Exportar', 'Compartir', 'Copiar', 'Ver', 'Detalles',
           'Activo', 'Inactivo', 'Procesando', 'Esperando', 'Aprobado', 'Rechazado',
           'Nombres', 'Apellidos', 'Pais', 'Codigo postal', 'Notas', 'Comentarios',
           'Resumen', 'Subtotal', 'Impuesto', 'Descuento', 'Moneda',
           'Anio', 'Semana', 'Dia', 'Mes', 'Hora', ' Peru']
}

def detect_language(text):
    """Detect the language of a text based on patterns"""
    text_lower = text.lower()
    scores = defaultdict(int)
    
    for lang, patterns in LANG_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in text_lower:
                scores[lang] += len(pattern)  # Weight by pattern length
    
    if scores:
        return max(scores, key=scores.get)
    return None

def extract_all_translations(content):
    """Extract all key-value pairs from the file"""
    kv_pattern = r"'([a-z_]+)':\s*'([^']*)'"
    all_kvs = defaultdict(list)
    
    for match in re.finditer(kv_pattern, content):
        key = match.group(1)
        value = match.group(2)
        all_kvs[key].append(value)
    
    return all_kvs

def classify_translations(all_kvs):
    """Classify each key's translations by detected language"""
    classified = defaultdict(lambda: defaultdict(list))
    detection_results = []
    
    for key, values in all_kvs.items():
        for value in values:
            detected = detect_language(value)
            if detected:
                classified[detected][key].append(value)
            else:
                # Default to Spanish for unclassified
                classified['es'][key].append(value)
            
            detection_results.append({
                'key': key,
                'value': value[:80],
                'detected': detected or 'es'
            })
    
    return classified, detection_results

def generate_fixed_file(classified):
    """Generate a fixed Dart file"""
    
    # Get all unique keys
    all_keys = set()
    for lang_kvs in classified.values():
        all_keys.update(lang_kvs.keys())
    
    # Sort keys for consistent output
    sorted_keys = sorted(all_keys)
    
    # Generate Dart code
    dart_code = '''// ============================================================================
// FIXED TRANSLATIONS FILE
// Generated by fix_translations.py
// ============================================================================

import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  
  static final Map<String, String> _translationCache = {};

  static const supportedLocales = [
    Locale('es'),
    Locale('en'),
    Locale('de'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return value!;
  }

  String t(String key) {
    final cacheKey = '${locale.languageCode}:$key';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }
    final result = _translate(key);
    _translationCache[cacheKey] = result;
    return result;
  }
  
  String _translate(String key) {
    final languageCode = locale.languageCode.toLowerCase();
    
    // Try the requested language first
    final value = _translations[languageCode]?[key];
    if (value != null && value.isNotEmpty && value != key) {
      return value;
    }
    
    // Fallback to English
    final enValue = _translations['en']?[key];
    if (enValue != null && enValue.isNotEmpty && enValue != key) {
      return enValue;
    }
    
    // Fallback to Spanish
    final esValue = _translations['es']?[key];
    if (esValue != null && esValue.isNotEmpty && esValue != key) {
      return esValue;
    }
    
    return key;
  }

  // ============================================================================
  // TRANSLATIONS - Properly organized by language
  // ============================================================================

  static final Map<String, Map<String, String>> _translations = {
'''
    
    # Add translations for each language
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        lang_kvs = classified.get(lang, {})
        lang_keys = sorted(lang_kvs.keys())
        
        dart_code += f"    '{lang}': {{\n"
        
        for key in lang_keys:
            # Get the first value (most common one)
            value = lang_kvs[key][0] if lang_kvs[key] else key
            # Escape single quotes
            value = value.replace("'", "\\'").replace('\\n', '\\\\n')
            dart_code += f"      '{key}': '{value}',\n"
        
        dart_code += "    },\n"
    
    dart_code += '''  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'de', 'fr', 'it', 'pt'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
'''
    
    return dart_code, len(sorted_keys)

def main():
    print("=" * 70)
    print(" FLUTTER TRANSLATION FIXER - ANALISIS COMPLETO")
    print("=" * 70)
    
    # Read the corrupted file
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"\n[*] Extrayendo todas las traducciones del archivo corrupto...")
    
    # Extract all key-value pairs
    all_kvs = extract_all_translations(content)
    print(f"    Total de pairs key-value encontrados: {sum(len(v) for v in all_kvs.values())}")
    print(f"    Total de keys unicas: {len(all_kvs)}")
    
    # Classify by language
    print(f"\n[*] Clasificando traducciones por idioma...")
    classified, detection_results = classify_translations(all_kvs)
    
    # Report per language
    print(f"\n{'=' * 70}")
    print(" TRADUCCIONES POR IDIOMA DETECTADO")
    print("=" * 70)
    
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        count = len(classified.get(lang, {}))
        total_values = sum(len(v) for v in classified.get(lang, {}).values())
        print(f"  {lang.upper()}: {count} keys, {total_values} valores")
    
    # Save detection report
    report = {
        'total_keys': len(all_kvs),
        'total_values': sum(len(v) for v in all_kvs.values()),
        'by_language': {lang: len(classified.get(lang, {})) for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']},
        'sample_detection': detection_results[:100]  # First 100 samples
    }
    
    with open(REPORT_FILE, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\n[OK] Reporte guardado: {REPORT_FILE}")
    
    # Generate fixed file
    print(f"\n[*] Generando archivo Dart fixed...")
    dart_code, key_count = generate_fixed_file(classified)
    
    with open(OUTPUT_FIXED, 'w', encoding='utf-8') as f:
        f.write(dart_code)
    
    print(f"[OK] Archivo fixed guardado: {OUTPUT_FIXED}")
    print(f"     Total de keys incluidas: {key_count}")
    
    print(f"\n{'=' * 70}")
    print(" SIGUIENTE PASO")
    print("=" * 70)
    print("""
El archivo app_localizations_fixed.dart ha sido generado.
Para aplicarlo:

1. Backup del archivo original:
   copy app_localizations.dart app_localizations_backup.dart

2. Reemplazar con el fixed:
   copy app_localizations_fixed.dart app_localizations.dart

3. Limpiar cache de Flutter:
   flutter clean && flutter pub get

4. Rebuild:
   flutter build web
""")

if __name__ == '__main__':
    main()
