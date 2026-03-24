#!/usr/bin/env python3
"""
SMART Translation Fixer - Uses key names + content to determine language
"""
import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"
OUTPUT_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations_fixed.dart"

# Language patterns in TRANSLATION VALUES
TRANSLATION_PATTERNS = {
    'de': {
        'words': {'Anmelden', 'Abmelden', 'Konto', 'Passwort', 'Sprache', 'Lager', 'Lieferung',
                  'Benachrichtigungen', 'Reservierungen', 'Abgeschlossen', 'Gepaeck', 'Kunden',
                  'Benutzer', 'E-Mail', 'Telefon', 'Adresse', 'Zeit', 'Datum', 'Preis',
                  'Gesamt', 'Zahlung', 'Tasche', 'Abholung', 'Bestaetigen', 'Abbrechen',
                  'Fehler', 'Erfolg', 'Ausstehend', 'Scannen', 'Statut', 'Verlauf',
                  'Einstellungen', 'Profil', 'Registrieren', 'Erstellen', 'Suchen',
                  'Drucken', 'Exportieren', 'Teilen', 'Kopieren', 'Ansehen', 'Details',
                  'Aktiv', 'Inaktiv', 'Wird', 'oder', 'mit', 'ist', 'das', 'Sie', 'wir',
                  'nicht', 'war', 'werden', 'konnen', 'habe', 'hat', 'haben', 'wird'},
        'bad_words': {' Peru', 'Cusco', 'Lima', ' Administrador', ' Administratoder', 'Almacen',
                      'Reserva', 'Cliente', 'Usuario', 'Precio', 'Cancelar', 'Confirmar'}
    },
    'fr': {
        'words': {'Connexion', 'Deconnecter', 'Creer', 'Compte', 'Langue', 'Entrepots', 'Livraison',
                  'Notifications', 'Reservations', 'Termine', 'Bagages', 'Client', 'Utilisateur',
                  'Telephone', 'Nom', 'Adresse', 'Heure', 'Date', 'Prix', 'Total', 'Paiement',
                  'Sac', 'Retrait', 'Confirmer', 'Annuler', 'Erreur', 'Succes', 'Reessayer',
                  'Scanner', 'Statut', 'Historique', 'Parametres', 'Profil', 'Accueil',
                  'Menu', 'Rechercher', 'Filtrer', 'Trier', 'Actualiser', 'Imprimer',
                  'Exporter', 'Partager', 'Copier', 'Voir', 'Details', 'Actif', 'Inactif',
                  'dans', 'pour', 'pas', 'une', 'les', 'des', 'est', 'avec', 'sont'},
        'bad_words': {' Peru', 'Cusco', 'Lima', ' Administrador', 'Almacen', 'Reserva',
                      'Cliente', 'Usuario', 'Precio', 'Iniciar', 'Cerrar', 'Confirmar'}
    },
    'it': {
        'words': {'Accedi', 'Disconnetti', 'Account', 'Password', 'Lingua', 'Magazzini', 'Consegna',
                  'Notifiche', 'Prenotazioni', 'Terminato', 'Bagagli', 'Cliente', 'Utente',
                  'Telefono', 'Nome', 'Indirizzo', 'Ora', 'Data', 'Prezzo', 'Totale', 'Pagamento',
                  'Borsa', 'Ritiro', 'Conferma', 'Annulla', 'Errore', 'Successo', 'Riprova',
                  'Scansiona', 'Codice', 'Stato', 'Cronologia', 'Impostazioni', 'Profilo',
                  'Home', 'Menu', 'Cerca', 'Filtra', 'Ordina', 'Aggiorna', 'Stampa',
                  'Esporta', 'Condividi', 'Copia', 'Vedi', 'Dettagli', 'Attivo', 'Inattivo',
                  'che', 'per', 'non', 'una', 'del', 'con', 'sono', 'nel', 'della'},
        'bad_words': {' Peru', 'Cusco', 'Lima', ' Administrador', 'Almacen', 'Reserva',
                      'Cliente', 'Usuario', 'Precio', 'Iniciar', 'Cerrar', 'Confirmar'}
    },
    'pt': {
        'words': {'Entrar', 'Sair', 'Cadastrar', 'Senha', 'Idioma', 'Armazens', 'Entrega',
                  'Notificacoes', 'Reservas', 'Concluido', 'Bagagem', 'Cliente', 'Usuario',
                  'Telefone', 'Nome', 'Endereco', 'Hora', 'Data', 'Preco', 'Total', 'Pagamento',
                  'Bolsa', 'Retirada', 'Confirmar', 'Cancelar', 'Erro', 'Sucesso', 'Tentar',
                  'Escanear', 'Codigo', 'Status', 'Historico', 'Configuracoes', 'Perfil',
                  'Inicio', 'Menu', 'Pesquisar', 'Filtrar', 'Ordenar', 'Atualizar',
                  'Imprimir', 'Exportar', 'Compartilhar', 'Copiar', 'Ver', 'Detalhes',
                  'para', 'com', 'que', 'uma', 'tem', 'por', 'seu', 'sua', 'nao',
                  'como', 'mais', 'foi', 'das', 'dos', 'tambem', 'Ativo', 'Inativo'},
        'bad_words': {' Peru', 'Cusco', 'Lima', ' Administrador', 'Almacen', 'Reserva',
                      'Cliente', 'Usuario', 'Precio', 'Iniciar', 'Cerrar', 'Confirmar'}
    },
    'en': {
        'words': {'Login', 'Logout', 'Register', 'Password', 'Email', 'Language', 'Warehouse',
                  'Delivery', 'Pickup', 'Notifications', 'Reservations', 'Completed', 'Bags',
                  'Client', 'User', 'Phone', 'Name', 'Address', 'Time', 'Date', 'Price',
                  'Total', 'Payment', 'Bag', 'Confirm', 'Cancel', 'Error', 'Success',
                  'Pending', 'Scan', 'Code', 'Status', 'History', 'Settings', 'Profile',
                  'Home', 'Menu', 'Search', 'Filter', 'Sort', 'Refresh', 'Print', 'Export',
                  'Share', 'Copy', 'View', 'Details', 'Active', 'Inactive', 'Processing',
                  'Waiting', 'Approved', 'Rejected', 'First Name', 'Last Name', 'Country',
                  'Notes', 'Comments', 'Summary', 'Subtotal', 'Tax', 'Discount', 'Currency',
                  'Year', 'Week', 'Day', 'Month', 'Hour', 'First', 'Last', 'Code',
                  'the', 'and', 'for', 'with', 'this', 'that', 'are', 'from', 'your',
                  'can', 'will', 'has', 'have', 'been', 'was', 'not', 'but', 'have',
                  'Make', 'Make sure', 'Select', 'Please', 'Required', 'Optional'},
        'bad_words': {' Peru', 'Cusco', 'Lima', ' Administrador', 'Almacen', 'Reserva',
                      'Cliente', 'Usuario', 'Precio', 'Iniciar', 'Cerrar', 'Confirmar',
                      'Benachrichtigungen', 'Lieferung', 'Reservierungen', 'Gepaeck',
                      'Notifications', 'Entrepots', 'Reservations', 'Bagages',
                      'Prenotazioni', 'Magazzini', 'Reservas', 'Armazens'}
    }
}

def detect_language(value):
    """Detect language from translation value with strict rules"""
    if not value:
        return None
    
    value_lower = value.lower()
    scores = {}
    
    for lang, patterns in TRANSLATION_PATTERNS.items():
        score = 0
        words = patterns['words']
        bad_words = patterns['bad_words']
        
        # Count matching words
        for word in words:
            if word.lower() in value_lower:
                score += len(word)  # Weight by word length
        
        # Check for bad/contaminating words
        for bad in bad_words:
            if bad.lower() in value_lower:
                score -= 50  # Heavy penalty
        
        scores[lang] = score
    
    if not scores:
        return None
    
    max_score = max(scores.values())
    if max_score <= 0:
        return None  # No clear match
    
    return max(scores, key=scores.get)

def extract_all():
    """Extract all key-value pairs"""
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    kv_pattern = r"'([a-z_]+)':\s*'([^']*)'"
    all_kvs = defaultdict(list)
    
    for match in re.finditer(kv_pattern, content):
        key = match.group(1)
        value = match.group(2)
        all_kvs[key].append(value)
    
    return all_kvs

def clean_and_classify(all_kvs):
    """Clean and classify translations"""
    classified = defaultdict(dict)
    
    for key, values in all_kvs.items():
        best_value = None
        best_lang = None
        best_score = -999
        
        for value in values:
            lang = detect_language(value)
            if lang:
                # Score this value
                patterns = TRANSLATION_PATTERNS[lang]
                score = 0
                value_lower = value.lower()
                
                for word in patterns['words']:
                    if word.lower() in value_lower:
                        score += len(word)
                
                for bad in patterns['bad_words']:
                    if bad.lower() in value_lower:
                        score -= 100
                
                if score > best_score:
                    best_score = score
                    best_value = value
                    best_lang = lang
        
        if best_value and best_lang:
            classified[best_lang][key] = best_value
        else:
            # Default to Spanish for unclassified
            classified['es'][key] = values[0]
    
    return classified

def generate_dart(classified):
    """Generate clean Dart file"""
    lines = []
    
    lines.append('// ============================================================================')
    lines.append('// FIXED TRANSLATIONS - Smart Clean')
    lines.append('// ============================================================================')
    lines.append('')
    lines.append("import 'package:flutter/widgets.dart';")
    lines.append('')
    lines.append('class AppLocalizations {')
    lines.append('  AppLocalizations(this.locale);')
    lines.append('  final Locale locale;')
    lines.append('  static final Map<String, String> _cache = {};')
    lines.append('  static const supportedLocales = [')
    lines.append("    Locale('es'), Locale('en'), Locale('de'), Locale('fr'), Locale('it'), Locale('pt'),")
    lines.append('  ];')
    lines.append('  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();')
    lines.append('  static AppLocalizations of(BuildContext c) => Localizations.of<AppLocalizations>(c, AppLocalizations)!;')
    lines.append('  String t(String k) { final ck = locale.languageCode + ":" + k; if (_cache.containsKey(ck)) return _cache[ck]!; final r = _tr(k); _cache[ck] = r; return r; }')
    lines.append('  String _tr(String k) { final l = locale.languageCode; var r = _t[l]?[k]; if (r != null && r.isNotEmpty && r != k) return r; r = _t["en"]?[k]; if (r != null && r.isNotEmpty && r != k) return r; r = _t["es"]?[k]; if (r != null && r.isNotEmpty && r != k) return r; return k; }')
    lines.append('  static final Map<String, Map<String, String>> _t = {')
    
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        keys = sorted(classified.get(lang, {}).keys())
        lines.append("    '" + lang + "': { // " + str(len(keys)))
        for key in keys:
            val = classified[lang][key]
            val = val.replace("'", "\\'").replace('\n', ' ').replace('\r', '')
            lines.append("      '" + key + "': '" + val + "',")
        lines.append('    },')
    
    lines.append('  };')
    lines.append('}')
    lines.append('class _Delegate extends LocalizationsDelegate<AppLocalizations> {')
    lines.append('  const _Delegate();')
    lines.append('  @override bool isSupported(Locale l) => ["es","en","de","fr","it","pt"].contains(l.languageCode);')
    lines.append('  @override Future<AppLocalizations> load(Locale l) async => AppLocalizations(l);')
    lines.append('  @override bool shouldReload(_Delegate old) => false;')
    lines.append('}')
    
    return '\n'.join(lines)

def main():
    print("=" * 70)
    print(" SMART TRANSLATION FIXER")
    print("=" * 70)
    
    all_kvs = extract_all()
    print(f"Total keys extracted: {len(all_kvs)}")
    
    classified = clean_and_classify(all_kvs)
    
    print("\nClassification:")
    total = 0
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        count = len(classified.get(lang, {}))
        total += count
        print(f"  {lang.upper()}: {count}")
    print(f"  TOTAL: {total}")
    
    dart = generate_dart(classified)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(dart)
    
    print(f"\n[OK] Saved: {OUTPUT_FILE}")
    print(f"     Lines: {len(dart.splitlines())}")

if __name__ == '__main__':
    main()
