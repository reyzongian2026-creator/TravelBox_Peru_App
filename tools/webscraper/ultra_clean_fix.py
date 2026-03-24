#!/usr/bin/env python3
"""
Ultra-aggressive Translation Cleaner
Detects and removes contaminated translations
"""
import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"
OUTPUT_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations_fixed.dart"

# Aggressive language patterns
LANG_PATTERNS = {
    # German - very distinctive words
    'de': set(['Anmelden', 'Abmelden', 'Konto', 'Passwort', 'Sprache', 'Lager', 'Lieferung',
               'Benachrichtigungen', 'Reservierungen', 'Abgeschlossen', 'Gepaeck', 'Kunden',
               'Benutzer', 'E-Mail', 'Telefon', 'Name', 'Adresse', 'Zeit', 'Datum',
               'Preis', 'Gesamt', 'Zahlung', 'Tasche', 'Abholung', 'Bestaetigen',
               'Abbrechen', 'Fehler', 'Erfolg', 'Ausstehend', 'Scannen', 'Code',
               'Statut', 'Verlauf', 'Einstellungen', 'Profil', 'Registrieren', 'Erstellen',
               'Startseite', 'Menue', 'Suchen', 'Filtern', 'Sortieren', 'Aktualisieren',
               'Drucken', 'Exportieren', 'Teilen', 'Kopieren', 'Ansehen', 'Details',
               'Gepäck', 'wird', 'nicht', 'oder', 'und', 'mit', 'auf', 'für', 'ist', 'das',
               'Sitz', 'Platz', 'Stunde', 'Tag', 'Woche', 'Monat', 'Jahr', 'Uhr']),
    
    # French - distinctive words
    'fr': set(['Connexion', 'Deconnecter', 'Creer', 'Compte', 'Langue', 'Entrepots', 'Livraison',
               'Notifications', 'Reservations', 'Termine', 'Bagages', 'Client', 'Utilisateur',
               'Email', 'Telephone', 'Nom', 'Adresse', 'Heure', 'Date', 'Prix',
               'Total', 'Paiement', 'Sac', 'Retrait', 'Confirmer', 'Annuler',
               'Erreur', 'Succes', 'Scanner', 'Code', 'Statut', 'Historique', 'Parametres',
               'Profil', 'Accueil', 'Menu', 'Rechercher', 'Filtrer', 'Trier', 'Actualiser',
               'Imprimer', 'Exporter', 'Partager', 'Copier', 'Voir', 'Details',
               'dans', 'pour', 'pas', 'une', 'les', 'des', 'est', 'avec', 'sont',
               'ce', 'ou', 'et', 'au', 'aux', 'que', 'qui', 'sur']),
    
    # Italian - distinctive words
    'it': set(['Accedi', 'Disconnetti', 'Account', 'Password', 'Lingua', 'Magazzini', 'Consegna',
               'Notifiche', 'Prenotazioni', 'Terminato', 'Bagagli', 'Cliente', 'Utente',
               'Email', 'Telefono', 'Nome', 'Indirizzo', 'Ora', 'Data', 'Prezzo',
               'Totale', 'Pagamento', 'Borsa', 'Ritiro', 'Conferma', 'Annulla',
               'Errore', 'Successo', 'Scansiona', 'Codice', 'Stato', 'Cronologia', 'Impostazioni',
               'Profilo', 'Home', 'Menu', 'Cerca', 'Filtra', 'Ordina', 'Aggiorna',
               'Stampa', 'Esporta', 'Condividi', 'Copia', 'Vedi', 'Dettagli',
               'che', 'per', 'non', 'una', 'del', 'con', 'sono', 'nel', 'della',
               'questo', 'questa', 'gli', 'le', 'da', 'al', 'o', 'e']),
    
    # Portuguese - distinctive words
    'pt': set(['Entrar', 'Sair', 'Cadastrar', 'Senha', 'Idioma', 'Armazens', 'Entrega',
               'Notificacoes', 'Reservas', 'Concluido', 'Bagagem', 'Cliente', 'Usuario',
               'Email', 'Telefone', 'Nome', 'Endereco', 'Hora', 'Data', 'Preco',
               'Total', 'Pagamento', 'Bolsa', 'Retirada', 'Confirmar', 'Cancelar',
               'Erro', 'Sucesso', 'Escanear', 'Codigo', 'Status', 'Historico', 'Configuracoes',
               'Perfil', 'Inicio', 'Menu', 'Pesquisar', 'Filtrar', 'Ordenar', 'Atualizar',
               'Imprimir', 'Exportar', 'Compartilhar', 'Copiar', 'Ver', 'Detalhes',
               'para', 'com', 'que', 'uma', 'tem', 'por', 'seu', 'sua', 'nao',
               'como', 'mais', 'foi', 'das', 'dos', 'tambem', 'ou', 'e']),
    
    # English - distinctive words
    'en': set(['Login', 'Logout', 'Register', 'Password', 'Language', 'Warehouse', 'Delivery',
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
               'Year', 'Week', 'Day', 'Month', 'Hour',
               'the', 'and', 'for', 'with', 'this', 'that', 'are', 'from',
               'your', 'you', 'can', 'will', 'has', 'have', 'been', 'was']),
    
    # Spanish - distinctive words
    'es': set(['Iniciar', 'Cerrar', 'Registrarse', 'Contrasena', 'Idioma', 'Almacen', 'Entrega',
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
               'Anio', 'Semana', 'Dia', 'Mes', 'Hora', ' Peru', 'Lima', 'Cusco',
               'que', 'con', 'para', 'por', 'del', 'los', 'las', 'una', 'unos', 'unas',
               'este', 'esta', 'estos', 'estas', 'ese', 'esa', 'esos', 'esas',
               'como', 'pero', 'mas', 'tambien', 'fue', 'son', 'hay', 'tiene'])
}

# Words that indicate contamination (should NOT appear together)
CONTAMINATION_INDICATORS = {
    'es': ['Reservierungen', 'Lieferung', 'Lager', 'Benachrichtigungen', 'Gepaeck',
           'Connexion', 'Deconnecter', 'Reservations', 'Entrepots', 'Bagages',
           'Prenotazioni', 'Consegna', 'Magazzini', 'Bagagli', 'Accedi',
           'Entrar', 'Sair', 'Armazens', 'Entrega', 'Reservas', 'Bagagem'],
    'en': ['Anmelden', 'Konto', 'Reservierungen', 'Lieferung', 'Benachrichtigungen',
           'Connexion', 'Reservations', 'Entrepots', 'Notifications',
           'Prenotazioni', 'Consegna', 'Notifiche', 'Magazzini',
           'Entrar', 'Sair', 'Armazens', 'Entrega', 'Reservas', 'Notificacoes'],
    'de': ['Reservas', 'Almacen', 'Iniciar', ' Peru', 'Cliente', 'Usuario',
           'Reservations', 'Entrepots', 'Bagages', 'Connexion',
           'Prenotazioni', 'Magazzini', 'Bagagli', 'Accedi',
           'Entrar', 'Armazens', 'Reservas', 'Inicio'],
    'fr': ['Reservas', 'Almacen', ' Peru', 'Lieferung', 'Lager', 'Benachrichtigungen',
           'Anmelden', 'Konto', 'Reservierungen', 'Gepaeck',
           'Prenotazioni', 'Magazzini', 'Bagagli', 'Accedi',
           'Entrar', 'Armazens', 'Reservas', 'Inicio'],
    'it': ['Reservas', 'Almacen', ' Peru', 'Lieferung', 'Lager', 'Benachrichtigungen',
           'Anmelden', 'Konto', 'Reservierungen', 'Gepaeck',
           'Connexion', 'Reservations', 'Entrepots', 'Bagages',
           'Entrar', 'Armazens', 'Reservas', 'Inicio'],
    'pt': ['Reservas', 'Almacen', 'Lieferung', 'Lager', 'Benachrichtigungen',
           'Anmelden', 'Konto', 'Reservierungen', 'Gepaeck',
           'Connexion', 'Reservations', 'Entrepots', 'Bagages',
           'Prenotazioni', 'Magazzini', 'Bagagli', 'Accedi']
}

def is_contaminated(text, target_lang):
    """Check if text is contaminated with other languages"""
    text_lower = text.lower()
    indicators = CONTAMINATION_INDICATORS.get(target_lang, [])
    
    for indicator in indicators:
        if indicator.lower() in text_lower:
            return True
    return False

def detect_language(text):
    """Detect language with contamination checking"""
    text_lower = text.lower()
    scores = defaultdict(int)
    
    for lang, patterns in LANG_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in text_lower:
                scores[lang] += 1
    
    if not scores or max(scores.values()) == 0:
        return None
    
    return max(scores, key=scores.get)

def extract_and_clean():
    """Extract translations and clean contaminated ones"""
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract all key-value pairs
    kv_pattern = r"'([a-z_]+)':\s*'([^']*)'"
    all_kvs = defaultdict(list)
    
    for match in re.finditer(kv_pattern, content):
        key = match.group(1)
        value = match.group(2)
        all_kvs[key].append(value)
    
    print(f"Total unique keys: {len(all_kvs)}")
    print(f"Total key-value pairs: {sum(len(v) for v in all_kvs.values())}")
    
    # Classify and clean
    cleaned = defaultdict(lambda: defaultdict(list))
    contaminated_count = 0
    
    for key, values in all_kvs.items():
        for value in values:
            detected = detect_language(value)
            
            if detected:
                # Check for contamination
                if is_contaminated(value, detected):
                    contaminated_count += 1
                    continue  # Skip contaminated translations
                
                cleaned[detected][key].append(value)
    
    print(f"\nContaminated translations removed: {contaminated_count}")
    
    # Count per language
    print(f"\nClean translations by language:")
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        count = len(cleaned.get(lang, {}))
        print(f"  {lang.upper()}: {count} keys")
    
    return cleaned, len(all_kvs)

def generate_fixed_dart(cleaned, total_keys):
    """Generate the fixed Dart file"""
    
    # Get all keys
    all_keys = set()
    for lang_data in cleaned.values():
        all_keys.update(lang_data.keys())
    
    sorted_keys = sorted(all_keys)
    
    # Build Dart code line by line
    lines = []
    lines.append('// ============================================================================')
    lines.append('// FIXED TRANSLATIONS FILE - CLEAN VERSION')
    lines.append('// Total keys: ' + str(len(sorted_keys)))
    lines.append('// ============================================================================')
    lines.append('')
    lines.append("import 'package:flutter/widgets.dart';")
    lines.append('')
    lines.append('class AppLocalizations {')
    lines.append('  AppLocalizations(this.locale);')
    lines.append('  final Locale locale;')
    lines.append('')
    lines.append('  static final Map<String, String> _cache = {};')
    lines.append('')
    lines.append('  static const supportedLocales = [')
    lines.append("    Locale('es'),")
    lines.append("    Locale('en'),")
    lines.append("    Locale('de'),")
    lines.append("    Locale('fr'),")
    lines.append("    Locale('it'),")
    lines.append("    Locale('pt'),")
    lines.append('  ];')
    lines.append('')
    lines.append('  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();')
    lines.append('')
    lines.append('  static AppLocalizations of(BuildContext context) {')
    lines.append("    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;")
    lines.append('  }')
    lines.append('')
    lines.append('  String t(String key) {')
    lines.append("    final cacheKey = locale.languageCode + ':' + key;")
    lines.append('    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;')
    lines.append('    final result = _translate(key);')
    lines.append('    _cache[cacheKey] = result;')
    lines.append('    return result;')
    lines.append('  }')
    lines.append('')
    lines.append('  String _translate(String key) {')
    lines.append('    final lang = locale.languageCode.toLowerCase();')
    lines.append('')
    lines.append('    // Try requested language')
    lines.append('    var result = _t[lang]?[key];')
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append('')
    lines.append('    // Fallback to English')
    lines.append("    result = _t['en']?[key];")
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append('')
    lines.append('    // Fallback to Spanish')
    lines.append("    result = _t['es']?[key];")
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append('')
    lines.append('    return key;')
    lines.append('  }')
    lines.append('')
    lines.append('  // ============================================================================')
    lines.append('  // TRANSLATIONS')
    lines.append('  // ============================================================================')
    lines.append('')
    lines.append('  static final Map<String, Map<String, String>> _t = {')
    
    # Add each language
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        lang_keys = sorted(cleaned.get(lang, {}).keys())
        lines.append("    '" + lang + "': { // " + str(len(lang_keys)) + " keys")
        
        for key in lang_keys:
            value = cleaned[lang][key][0]  # First value
            value = value.replace("'", "\\'").replace('\n', ' ').replace('\r', '')
            lines.append("      '" + key + "': '" + value + "',")
        
        lines.append("    },")
    
    lines.append('  };')
    lines.append('}')
    lines.append('')
    lines.append('class _Delegate extends LocalizationsDelegate<AppLocalizations> {')
    lines.append('  const _Delegate();')
    lines.append('')
    lines.append('  @override')
    lines.append("  bool isSupported(Locale locale) => ['es', 'en', 'de', 'fr', 'it', 'pt'].contains(locale.languageCode);")
    lines.append('')
    lines.append('  @override')
    lines.append('  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);')
    lines.append('')
    lines.append('  @override')
    lines.append('  bool shouldReload(_Delegate old) => false;')
    lines.append('}')
    
    dart = '\n'.join(lines)
    
    return dart, len(sorted_keys)

def main():
    print("=" * 70)
    print(" ULTRA CLEAN TRANSLATION FIXER")
    print("=" * 70)
    
    cleaned, total_keys = extract_and_clean()
    dart, final_count = generate_fixed_dart(cleaned, total_keys)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(dart)
    
    print(f"\n[OK] Fixed file saved: {OUTPUT_FILE}")
    print(f"     Final key count: {final_count}")
    print(f"     File lines: {len(dart.splitlines())}")

if __name__ == '__main__':
    main()
