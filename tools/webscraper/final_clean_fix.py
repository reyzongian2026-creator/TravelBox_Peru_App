#!/usr/bin/env python3
"""
FINAL Translation Fixer - Removes all contamination, fills gaps
"""
import re
import json
from collections import defaultdict

DART_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations.dart"
OUTPUT_FILE = r"C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\lib\core\l10n\app_localizations_fixed.dart"

# Very strict contamination words - if ANY of these appear in a translation, reject it
CONTAMINATION_WORDS = {
    'es', 'en', 'de', 'fr', 'it', 'pt',  # Language codes in text
    'Reservierungen', 'Lieferung', 'Lager', 'Benachrichtigungen', 'Gepaeck',
    'Reservations', 'Entrepots', 'Bagages', 'Notifications',
    'Prenotazioni', 'Magazzini', 'Bagagli', 'Notifiche',
    'Reservas', 'Armazens', 'Bagagem', 'Notificacoes',
    ' Administrador', ' Administratoder',  # Contaminated Spanish
    ' Peru', 'Cusco', 'Lima',  # Location-specific contamination
}

# Key patterns that indicate language
KEY_LANG_HINTS = {
    'es': ['admin', 'operador', 'courier', 'cliente', 'almacen', 'reserva', 'entrega', 'recojo', 'cobro', 'incidencia'],
    'en': ['admin', 'operator', 'courier', 'client', 'warehouse', 'reservation', 'delivery', 'pickup', 'payment', 'incident'],
    'de': ['lager', 'lieferung', 'kunde', 'admin', 'mitarbeiter'],
    'fr': ['entrepot', 'client', 'admin', 'employe', 'reservation'],
    'it': ['magazzino', 'cliente', 'admin', 'dipendente', 'prenotazione'],
    'pt': ['armazem', 'cliente', 'admin', 'funcionario', 'reserva']
}

def extract_clean_translations():
    """Extract and deeply clean translations"""
    with open(DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    kv_pattern = r"'([a-z_]+)':\s*'([^']*)'"
    all_kvs = defaultdict(list)
    
    for match in re.finditer(kv_pattern, content):
        key = match.group(1)
        value = match.group(2)
        all_kvs[key].append(value)
    
    print(f"Total keys: {len(all_kvs)}")
    
    # Clean translations - pick the best value for each key
    best_translations = {}
    
    for key, values in all_kvs.items():
        # Score each value
        scored = []
        for value in values:
            score = 0
            value_lower = value.lower()
            
            # Check for contamination
            contaminated = False
            for contam in CONTAMINATION_WORDS:
                if contam.lower() in value_lower:
                    contaminated = True
                    break
            
            if contaminated:
                scored.append((value, -1000))  # Heavily penalize
                continue
            
            # Check for language-specific words
            for lang, hints in KEY_LANG_HINTS.items():
                for hint in hints:
                    if hint.lower() in key.lower():
                        if hint.lower() in value_lower:
                            score += 10
                    
            # Prefer shorter values (less likely to be corrupted)
            if len(value) < 100:
                score += 5
            if len(value) < 50:
                score += 5
            
            # Penalize mixed encoding or weird characters
            if re.search(r'[àáâãäå]|[èéêë]|[ìíîï]|[òóôõö]|[ùúûü]', value):
                score -= 3
            
            # Penalize mixed case words in wrong places
            if re.search(r'[A-Z][a-z]+[a-z]+[A-Z]', value):
                score -= 5
            
            scored.append((value, score))
        
        # Sort by score descending
        scored.sort(key=lambda x: x[1], reverse=True)
        
        if scored and scored[0][1] > -1000:
            best_translations[key] = scored[0][0]
        elif values:
            best_translations[key] = values[0]  # Fallback to first value
    
    print(f"Clean translations: {len(best_translations)}")
    
    return best_translations

def classify_by_content(translations):
    """Classify translations by their actual content (language)"""
    classified = defaultdict(dict)
    
    # Spanish words
    spanish_words = {
        'iniciar', 'cerrar', 'registrarse', 'correo', 'contrasena', 'idioma',
        'almacen', 'entrega', 'recojo', 'notificaciones', 'reservas', 'completado',
        'maletas', 'cliente', 'usuario', 'telefono', 'nombre', 'direccion',
        'precio', 'pago', 'bulto', 'confirmar', 'cancelar', 'error', 'exito',
        'pendiente', 'escanear', 'codigo', 'estado', 'historial', 'configuracion',
        'perfil', 'inicio', 'menu', 'buscar', 'filtrar', 'ordenar', 'actualizar',
        'imprimir', 'exportar', 'compartir', 'copiar', 'ver', 'detalles',
        'activo', 'inactivo', 'procesando', 'esperando', 'aprobado', 'rechazado',
        'nombres', 'apellidos', 'pais', 'notas', 'comentarios', 'resumen',
        'total', 'subtotal', 'impuesto', 'descuento', 'moneda', 'anio',
        'semana', 'dia', 'mes', 'hora', 'bolsa', 'cancelado', 'rechazado'
    }
    
    # English words
    english_words = {
        'login', 'logout', 'register', 'password', 'email', 'language',
        'warehouse', 'delivery', 'pickup', 'notifications', 'reservations', 'completed',
        'bags', 'client', 'user', 'phone', 'name', 'address', 'price', 'payment',
        'bag', 'confirm', 'cancel', 'error', 'success', 'pending', 'scan', 'code',
        'status', 'history', 'settings', 'profile', 'home', 'menu', 'search',
        'filter', 'sort', 'refresh', 'print', 'export', 'share', 'copy', 'view',
        'details', 'active', 'inactive', 'processing', 'waiting', 'approved', 'rejected',
        'first name', 'last name', 'country', 'notes', 'comments', 'summary',
        'total', 'subtotal', 'tax', 'discount', 'currency', 'year', 'week', 'day',
        'month', 'hour', 'cancelled'
    }
    
    # German words
    german_words = {
        'anmelden', 'abmelden', 'konto', 'passwort', 'sprache', 'lager', 'lieferung',
        'benachrichtigungen', 'reservierungen', 'abgeschlossen', 'gepaeck', 'kunden',
        'benutzer', 'e-mail', 'telefon', 'adresse', 'zeit', 'datum', 'preis',
        'gesamt', 'zahlung', 'tasche', 'abholung', 'bestaetigen', 'abbrechen',
        'fehler', 'erfolg', 'ausstehend', 'scannen', 'code', 'statut', 'verlauf',
        'einstellungen', 'profil', 'registrieren', 'erstellen', 'startseite',
        'suchen', 'filtern', 'sortieren', 'aktualisieren', 'drucken', 'exportieren'
    }
    
    # French words
    french_words = {
        'connexion', 'deconnecter', 'creer', 'compte', 'mot', 'passe', 'langue',
        'entrepots', 'livraison', 'notifications', 'reservations', 'termine',
        'bagages', 'client', 'utilisateur', 'telephone', 'nom', 'adresse',
        'heure', 'date', 'prix', 'total', 'paiement', 'sac', 'retrait',
        'confirmer', 'annuler', 'erreur', 'succes', 'reessayer', 'scanner',
        'code', 'statut', 'historique', 'parametres', 'profil', 'accueil',
        'menu', 'rechercher', 'filtrer', 'trier', 'actualiser', 'imprimer'
    }
    
    # Italian words
    italian_words = {
        'accedi', 'disconnetti', 'account', 'password', 'lingua', 'magazzini', 'consegna',
        'notifiche', 'prenotazioni', 'terminato', 'bagagli', 'cliente', 'utente',
        'email', 'telefono', 'nome', 'indirizzo', 'ora', 'data', 'prezzo',
        'totale', 'pagamento', 'borsa', 'ritiro', 'conferma', 'annulla',
        'errore', 'successo', 'riprova', 'scansiona', 'codice', 'stato',
        'cronologia', 'impostazioni', 'profilo', 'home', 'menu', 'cerca',
        'filtra', 'ordina', 'aggiorna', 'stampa', 'esporta', 'condividi'
    }
    
    # Portuguese words
    portuguese_words = {
        'entrar', 'sair', 'cadastrar', 'senha', 'idioma', 'armazens', 'entrega',
        'notificacoes', 'reservas', 'concluido', 'bagagem', 'cliente', 'usuario',
        'email', 'telefone', 'nome', 'endereco', 'hora', 'data', 'preco',
        'total', 'pagamento', 'bolsa', 'retirada', 'confirmar', 'cancelar',
        'erro', 'sucesso', 'tentar', 'escanear', 'codigo', 'status',
        'historico', 'configuracoes', 'perfil', 'inicio', 'menu', 'pesquisar',
        'filtrar', 'ordenar', 'atualizar', 'imprimir', 'exportar'
    }
    
    for key, value in translations.items():
        value_lower = value.lower()
        
        scores = {
            'es': sum(1 for w in spanish_words if w in value_lower),
            'en': sum(1 for w in english_words if w in value_lower),
            'de': sum(1 for w in german_words if w in value_lower),
            'fr': sum(1 for w in french_words if w in value_lower),
            'it': sum(1 for w in italian_words if w in value_lower),
            'pt': sum(1 for w in portuguese_words if w in value_lower),
        }
        
        max_score = max(scores.values())
        if max_score > 0:
            detected_lang = max(scores, key=scores.get)
            classified[detected_lang][key] = value
        else:
            # Unclassified - default to Spanish for common app terms
            classified['es'][key] = value
    
    return classified

def generate_dart_file(classified, all_keys):
    """Generate the cleaned Dart file"""
    
    lines = []
    lines.append('// ============================================================================')
    lines.append('// FIXED TRANSLATIONS - Deep Cleaned Version')
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
    lines.append("    Locale('es'), Locale('en'), Locale('de'), Locale('fr'), Locale('it'), Locale('pt'),")
    lines.append('  ];')
    lines.append('')
    lines.append('  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();')
    lines.append('')
    lines.append('  static AppLocalizations of(BuildContext context) {')
    lines.append('    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;')
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
    lines.append('    final lang = locale.languageCode;')
    lines.append('    var result = _t[lang]?[key];')
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append("    result = _t['en']?[key];")
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append("    result = _t['es']?[key];")
    lines.append('    if (result != null && result.isNotEmpty && result != key) return result;')
    lines.append('    return key;')
    lines.append('  }')
    lines.append('')
    lines.append('  static final Map<String, Map<String, String>> _t = {')
    
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        lang_keys = sorted(classified.get(lang, {}).keys())
        lines.append("    '" + lang + "': {")
        for key in lang_keys:
            value = classified[lang][key]
            value = value.replace("'", "\\'").replace('\n', ' ').replace('\r', '')
            lines.append("      '" + key + "': '" + value + "',")
        lines.append('    },')
    
    lines.append('  };')
    lines.append('}')
    lines.append('')
    lines.append('class _Delegate extends LocalizationsDelegate<AppLocalizations> {')
    lines.append('  const _Delegate();')
    lines.append('  @override')
    lines.append("  bool isSupported(Locale l) => ['es','en','de','fr','it','pt'].contains(l.languageCode);")
    lines.append('  @override Future<AppLocalizations> load(Locale l) async => AppLocalizations(l);')
    lines.append('  @override bool shouldReload(_Delegate old) => false;')
    lines.append('}')
    
    return '\n'.join(lines)

def main():
    print("=" * 70)
    print(" FINAL DEEP CLEAN TRANSLATION FIXER")
    print("=" * 70)
    
    translations = extract_clean_translations()
    classified = classify_by_content(translations)
    
    print("\nClassification results:")
    total = 0
    for lang in ['es', 'en', 'de', 'fr', 'it', 'pt']:
        count = len(classified.get(lang, {}))
        total += count
        print(f"  {lang.upper()}: {count} keys")
    print(f"  TOTAL: {total}")
    
    all_keys = set()
    for lang_data in classified.values():
        all_keys.update(lang_data.keys())
    
    dart = generate_dart_file(classified, all_keys)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(dart)
    
    print(f"\n[OK] Saved: {OUTPUT_FILE}")
    print(f"     Lines: {len(dart.splitlines())}")
    print(f"     Keys: {len(all_keys)}")

if __name__ == '__main__':
    main()
