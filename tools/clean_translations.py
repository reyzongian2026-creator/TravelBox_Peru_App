#!/usr/bin/env python3
"""
Script para limpiar traducciones contaminadas en app_localizations.dart
Solo reemplaza valores que están en el idioma incorrecto, sin eliminar keys.
"""

import re
import json
from pathlib import Path

# Patrones de palabras que indican contaminación
# Estas palabras NO deberían aparecer en ciertos idiomas
CONTAMINATION_PATTERNS = {
    'es': [],  # Español limpio
    'en': [
        # Palabras que indican contaminación de español
        'Administrador', 'Operador', 'Courier', 'Cliente', 'Reserva', 'Incidencia',
        'Almacen', 'almacen', 'Equipaje', 'equipaje', 'Cancelar', 'Cobros',
        'Pendiente', 'pendiente', 'Actualizar', 'confirmar', 'Completar',
        # Palabras de otros idiomas
        'Administrateur', 'Operateur', 'Operadoder', 'Andere', 'Benutzer',
        'Administrador', 'Gestor', 'Kunde', 'Cliente', 'Bestellung', 'Lieferung',
    ],
    'de': [
        # Palabras que no son alemanas
        'Administrador', 'admin', 'Incidencias', 'incidencias', 'Operadoder',
        'Operador', 'Sopoderte', 'Tablero', 'Reservas', 'Reservierungen',
        'Cancelar', 'Cobros', 'Registros', 'poder', 'monitodereo', 'oderden',
        'Histoderial', 'todavia', 'nuevas', 'Laden', 'Chamadas',
        'Validar', 'Codanscidencia', 'etapa', 'Aprobacion', 'Aprobacion',
        'Gepack', 'Liefer', 'Bestellung', 'Abhol', 'Kasse', 'Lager',
    ],
    'fr': [
        # Palabras que no son francesas
        'Administrador', 'Operador', 'Andere', 'danscidencias', 'dans',
        'Trackdansg', 'Pagdansa', 'mdans', 'Admdans', 'Sdans', 'dans',
        'Gestionado', 'Elimdansara', 'Codanscidencia', 'Reservas', 'Cobros',
    ],
    'it': [
        # Palabras que no son italianas
        'Acceso', 'Operacion', 'Centro', 'Evolucion', 'Entrega', 'Apertura',
        'Operazione', 'Operadoder', 'preNonazione', 'Non', 'toda', 'poutada',
        'TelefoNon', 'oden', 'Consegua', 'poque', 'Borado', 'cooderdenadas',
        'Non', 'valido', 'vehicolo', 'Operazioni',
    ],
    'pt': [
        # Palabras que no son portuguesas
        'Kein', 'Tracking', 'verfugbar', 'Keine', 'Gestionado', 'Naoumal',
        'Nao', 'ItaliaNao', 'Reembolsar', 'Reembolso', 'Aprobacion',
        'Cargar', 'Volta', 'Voltar', 'Endereco', 'Atualizar', 'Verspatung',
        'Nao', 'carregar', 'Verificar', 'Codigo', 'horario', 'Status',
    ]
}

# Traducciones correctas conocidas (fallback manual)
CORRECT_TRANSLATIONS = {
    'en': {
        'admin': 'Admin',
        'admin_dashboard_tab_incidents': 'Incidents',
        'admin_incidents_pdf_title': 'TravelBox Resolved Incidents',
        'admin_incidents_resolved_title': 'Resolved incidents',
        'dashboard_open_incidents': 'Open incidents',
        'incidencias': 'Incidents',
        'operator_kpi_incidents': 'Incidents',
        'operator_dashboard_title': 'Operations panel',
        'operator_dashboard_intro': 'Daily operations: cash collection, reservation control, and incident tracking.',
        'operator_kpi_pending_cash': 'Pending collections',
        'operator_kpi_active_reservations': 'Active reservations',
        'operator_reservations_subtitle': 'Search by code, status changes, and traceability',
        'operator_qr_subtitle': 'Scan reservation, tag luggage, and close delivery with PIN',
        'operator_pending_approvals_suffix': 'pending approvals',
        'operator_pending_approvals_subtitle': 'There are delivery handoffs waiting for operator/admin validation.',
        'operator_no_pending_cash': 'No pending collections to validate.',
        'operator_recent_pending_title': 'Recent pending',
        'operator_attempt': 'Attempt',
        'operator_reservation': 'Reservation',
        'operator_pending_cash_load_failed': 'Could not load pending collections',
        'my_reservations_title': 'My reservations',
        'my_reservations_load_failed': 'Could not load reservations',
        'my_reservations_empty': 'You don\'t have reservations yet.',
        'my_reservations_browse_warehouses': 'Browse warehouses',
        'my_reservations_history_title': 'Reservations history',
        'my_reservations_page': 'Page',
        'my_reservations_of': 'of',
        'my_reservations_latest_only': 'This is your most current reservation. No additional history yet.',
        'my_reservations_latest_title': 'Most current reservation',
        'my_reservations_bags': 'bags',
        'my_reservations_total_prefix': 'Total',
        'my_reservations_code_prefix': 'Code',
    },
    'de': {
        'admin': 'Admin',
        'operator_dashboard_title': 'Operatives Panel',
        'operator_dashboard_intro': 'Taglicher Betrieb: Kasseninkasso, Reservierungskontrolle und Vorfallverfolgung.',
        'operator_kpi_pending_cash': 'Ausstehende Inkassen',
        'operator_kpi_active_reservations': 'Aktive Reservierungen',
        'operator_kpi_incidents': 'Vorfalle',
        'operator_reservations_subtitle': 'Suche nach Code, Statusandern und Ruckverfolgbarkeit',
        'operator_qr_subtitle': 'Reservierung scannen, Gepack etikettieren und Ubergabe mit PIN abschliessen',
        'operator_pending_approvals_suffix': 'ausstehende Genehmigungen',
        'operator_pending_approvals_subtitle': 'Es gibt Liefereubergaben, die auf Operator/Admin-Validierung warten.',
        'operator_no_pending_cash': 'Keine ausstehenden Inkassen zu validieren.',
        'operator_recent_pending_title': 'Kurzlich ausstehend',
        'operator_attempt': 'Versuch',
        'operator_reservation': 'Reservierung',
        'operator_pending_cash_load_failed': 'Ausstehende Inkassen konnten nicht geladen werden',
        'my_reservations_title': 'Meine Reservierungen',
        'my_reservations_load_failed': 'Reservierungen konnten nicht geladen werden',
        'my_reservations_empty': 'Sie haben noch keine Reservierungen.',
        'my_reservations_browse_warehouses': 'Lager suchen',
        'my_reservations_history_title': 'Reservierungsverlauf',
        'my_reservations_page': 'Seite',
        'my_reservations_of': 'von',
        'my_reservations_latest_only': 'Dies ist Ihre aktuellste Reservierung. Kein weiterer Verlauf vorhanden.',
        'my_reservations_latest_title': 'Aktuellste Reservierung',
        'my_reservations_bags': 'Gepackstucke',
        'my_reservations_total_prefix': 'Gesamt',
        'my_reservations_code_prefix': 'Code',
    },
    'fr': {
        'admin': 'Admin',
        'operator_dashboard_title': 'Panneau operatif',
        'operator_dashboard_intro': 'Operations quotidiennes: encaissement, controle des reservations et suivi des incidents.',
        'operator_kpi_pending_cash': 'Encaissements en attente',
        'operator_kpi_active_reservations': 'Reservations actives',
        'operator_kpi_incidents': 'Incidents',
        'operator_reservations_subtitle': 'Recherche par code, changements de statut et traçabilité',
        'operator_qr_subtitle': 'Scanner reservation, etiqueter bagages et fermer livraison avec PIN',
        'operator_pending_approvals_suffix': 'approbations en attente',
        'operator_pending_approvals_subtitle': 'Il y a des remises de livraison en attente de validation operateur/admin.',
        'operator_no_pending_cash': 'Pas d encaissements en attente a valider.',
        'operator_recent_pending_title': 'Recents en attente',
        'operator_attempt': 'Tentative',
        'operator_reservation': 'Reservation',
        'operator_pending_cash_load_failed': 'Impossible de charger les encaissements en attente',
        'my_reservations_title': 'Mes reservations',
        'my_reservations_load_failed': 'Impossible de charger les reservations',
        'my_reservations_empty': 'Vous n avez pas encore de reservations.',
        'my_reservations_browse_warehouses': 'Rechercher entrepots',
        'my_reservations_history_title': 'Historique des reservations',
        'my_reservations_page': 'Page',
        'my_reservations_of': 'de',
        'my_reservations_latest_only': 'Ceci est votre reservation la plus actuelle. Pas d historique supplementaire.',
        'my_reservations_latest_title': 'Reservation la plus actuelle',
        'my_reservations_bags': 'bagages',
        'my_reservations_total_prefix': 'Total',
        'my_reservations_code_prefix': 'Code',
    },
    'it': {
        'admin': 'Admin',
        'operator_dashboard_title': 'Pannello operativo',
        'operator_dashboard_intro': 'Operazioni quotidiane: incasso, controllo prenotazioni e tracciamento incidenti.',
        'operator_kpi_pending_cash': 'Incassi in sospeso',
        'operator_kpi_active_reservations': 'Prenotazioni attive',
        'operator_kpi_incidents': 'Indennita',
        'operator_reservations_subtitle': 'Ricerca per codice, cambi di stato e tracciabilita',
        'operator_qr_subtitle': 'Scansiona prenotazione, etichetta bagagli e chiudi consegna con PIN',
        'operator_pending_approvals_suffix': 'approvazioni in sospeso',
        'operator_pending_approvals_subtitle': 'Ci sono consegne in attesa di validazione operatore/admin.',
        'operator_no_pending_cash': 'Nessun incasso in sospeso da validare.',
        'operator_recent_pending_title': 'Recenti in sospeso',
        'operator_attempt': 'Tentativo',
        'operator_reservation': 'Prenotazione',
        'operator_pending_cash_load_failed': 'Impossibile caricare incassi in sospeso',
        'my_reservations_title': 'Le mie prenotazioni',
        'my_reservations_load_failed': 'Impossibile caricare prenotazioni',
        'my_reservations_empty': 'Non hai ancora prenotazioni.',
        'my_reservations_browse_warehouses': 'Cerca magazzini',
        'my_reservations_history_title': 'Storico prenotazioni',
        'my_reservations_page': 'Pagina',
        'my_reservations_of': 'di',
        'my_reservations_latest_only': 'Questa e la tua prenotazione piu attuale. Nessuno storico aggiuntivo.',
        'my_reservations_latest_title': 'Prenotazione piu attuale',
        'my_reservations_bags': 'bagagli',
        'my_reservations_total_prefix': 'Totale',
        'my_reservations_code_prefix': 'Codice',
    },
    'pt': {
        'admin': 'Admin',
        'operator_dashboard_title': 'Painel operacional',
        'operator_dashboard_intro': 'Operacoes diarias: recebimento, controle de reservas e rastreamento de incidentes.',
        'operator_kpi_pending_cash': 'Recebimentos pendentes',
        'operator_kpi_active_reservations': 'Reservas ativas',
        'operator_kpi_incidents': 'Incidencias',
        'operator_reservations_subtitle': 'Pesquisa por codigo, alteracoes de status e rastreabilidade',
        'operator_qr_subtitle': 'Escanear reserva, etiquetar bagagens e fechar entrega com PIN',
        'operator_pending_approvals_suffix': 'aprovacoes pendentes',
        'operator_pending_approvals_subtitle': 'Ha entregas aguardando validacao do operador/admin.',
        'operator_no_pending_cash': 'Nenhum recebimento pendente para validar.',
        'operator_recent_pending_title': 'Pendentes recentes',
        'operator_attempt': 'Tentativa',
        'operator_reservation': 'Reserva',
        'operator_pending_cash_load_failed': 'Nao foi possivel carregar recebimentos pendentes',
        'my_reservations_title': 'Minhas reservas',
        'my_reservations_load_failed': 'Nao foi possivel carregar reservas',
        'my_reservations_empty': 'Voce ainda nao tem reservas.',
        'my_reservations_browse_warehouses': 'Buscar armazens',
        'my_reservations_history_title': 'Historico de reservas',
        'my_reservations_page': 'Pagina',
        'my_reservations_of': 'de',
        'my_reservations_latest_only': 'Esta e sua reserva mais atual. Nenhum historico adicional.',
        'my_reservations_latest_title': 'Reserva mais atual',
        'my_reservations_bags': 'bagagens',
        'my_reservations_total_prefix': 'Total',
        'my_reservations_code_prefix': 'Codigo',
    }
}

def detect_contamination(lang, value):
    """Detecta si una traduccion esta contaminada con palabras de otros idiomas."""
    if lang not in CONTAMINATION_PATTERNS:
        return False
    
    for bad_word in CONTAMINATION_PATTERNS[lang]:
        if bad_word.lower() in value.lower():
            return True
    return False

def clean_file(input_path, output_path):
    """Limpia las traducciones contaminadas en el archivo."""
    content = Path(input_path).read_text(encoding='utf-8')
    
    # Reemplazar traducciones contaminadas conocidas
    for lang, translations in CORRECT_TRANSLATIONS.items():
        for key, correct_value in translations.items():
            # Pattern para encontrar la traduccion en el mapa del idioma
            # Busca el key en la seccion del idioma especifico
            pattern = rf"('{lang}':\s*\{{[^}}]*)'{key}':\s*'[^']*'"
            replacement = rf"\1'{key}': '{correct_value}'"
            content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Guardar archivo limpio
    Path(output_path).write_text(content, encoding='utf-8')
    print(f"Archivo limpio guardado en: {output_path}")

if __name__ == '__main__':
    input_file = Path(__file__).parent.parent / 'lib' / 'core' / 'l10n' / 'app_localizations.dart'
    output_file = Path(__file__).parent.parent / 'lib' / 'core' / 'l10n' / 'app_localizations_cleaned.dart'
    
    clean_file(input_file, output_file)
    print("Limpieza completada!")
