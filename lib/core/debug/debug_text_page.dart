import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations_fixed.dart';

class DebugTextPage extends ConsumerStatefulWidget {
  const DebugTextPage({super.key});

  @override
  ConsumerState<DebugTextPage> createState() => _DebugTextPageState();
}

class _DebugTextPageState extends ConsumerState<DebugTextPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allTranslationKeys = _getAllTranslationKeys(l10n);

    final filteredKeys = allTranslationKeys.where((key) {
      if (_searchQuery.isEmpty) return true;
      final value = l10n.t(key);
      return key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          value.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Traducciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar',
            onPressed: () => _exportKeys(context, filteredKeys, l10n),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar keys o textos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Total keys: ${allTranslationKeys.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Text(
                  'Filtrados: ${filteredKeys.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredKeys.isEmpty
                ? const Center(child: Text('No se encontraron resultados'))
                : ListView.builder(
                    itemCount: filteredKeys.length,
                    itemBuilder: (context, index) {
                      final key = filteredKeys[index];
                      final value = l10n.t(key);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            key,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            value,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              // Copy to clipboard functionality would go here
                            },
                          ),
                          isThreeLine: value.length > 50,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<String> _getAllTranslationKeys(AppLocalizations l10n) {
    final Map<String, String> translationsMap = {
      'about': l10n.t('about'),
      'active': l10n.t('active'),
      'activeSessions': l10n.t('activeSessions'),
      'add': l10n.t('add'),
      'address': l10n.t('address'),
      'admin': l10n.t('admin'),
      'admin_dashboard_title': l10n.t('admin_dashboard_title'),
      'admin_incidents': l10n.t('admin_incidents'),
      'admin_warehouses_title': l10n.t('admin_warehouses_title'),
      'almacen': l10n.t('almacen'),
      'almacen_mas_cercano': l10n.t('almacen_mas_cercano'),
      'app_name': l10n.t('app_name'),
      'beam': l10n.t('beam'),
      'cancelar': l10n.t('cancelar'),
      'ciudad': l10n.t('ciudad'),
      'city': l10n.t('city'),
      'checkout': l10n.t('checkout'),
      'cognito': l10n.t('cognito'),
      'confirmar': l10n.t('confirmar'),
      'country': l10n.t('country'),
      'courier': l10n.t('courier'),
      'create': l10n.t('create'),
      'credenciales': l10n.t('credenciales'),
      'cuenta': l10n.t('cuenta'),
      'currency': l10n.t('currency'),
      'dashboard': l10n.t('dashboard'),
      'delivery': l10n.t('delivery'),
      'descuentos': l10n.t('descuentos'),
      'discover': l10n.t('discover'),
      'discover_title_nearby': l10n.t('discover_title_nearby'),
      'document': l10n.t('document'),
      'documentType': l10n.t('documentType'),
      'dni': l10n.t('dni'),
      'edit': l10n.t('editar'),
      'eliminar': l10n.t('eliminar'),
      'email': l10n.t('email'),
      'emergencyContact': l10n.t('emergencyContact'),
      'entrega': l10n.t('entrega'),
      'error': l10n.t('error'),
      'es': l10n.t('es'),
      'espanol': l10n.t('espanol'),
      'estado': l10n.t('estado'),
      'export': l10n.t('export'),
      'filter': l10n.t('filter'),
      'forgotPassword': l10n.t('forgotPassword'),
      'guardar': l10n.t('guardar'),
      'home': l10n.t('home'),
      'id': l10n.t('id'),
      'inactive': l10n.t('inactive'),
      'incidencias': l10n.t('incidencias'),
      'btn_language': l10n.t('btn_language'),
      'lang_es': l10n.t('lang_es'),
      'lang': l10n.t('lang'),
      'language': l10n.t('language'),
      'lastLogin': l10n.t('lastLogin'),
      'latitude': l10n.t('latitude'),
      'loading': l10n.t('loading'),
      'login': l10n.t('login'),
      'logout': l10n.t('logout'),
      'longitude': l10n.t('longitude'),
      'map': l10n.t('map'),
      'mapa': l10n.t('mapa'),
      'mh': l10n.t('mh'),
      'my_reservations_title': l10n.t('my_reservations_title'),
      'name': l10n.t('name'),
      'nameLabel': l10n.t('nameLabel'),
      'nationality': l10n.t('nationality'),
      'new': l10n.t('nuevo'),
      'next': l10n.t('next'),
      'no': l10n.t('no'),
      'notifications': l10n.t('notifications'),
      'number': l10n.t('number'),
      'occupation': l10n.t('occupation'),
      'onboarding_start_now': l10n.t('onboarding_start_now'),
      'operator': l10n.t('operator'),
      'password': l10n.t('password'),
      'password confirmation': l10n.t('password confirmation'),
      'payment': l10n.t('payment'),
      'peru': l10n.t('peru'),
      'phone': l10n.t('phone'),
      'phoneNumber': l10n.t('phoneNumber'),
      'photos': l10n.t('photos'),
      'pickup': l10n.t('pickup'),
      'precio': l10n.t('precio'),
      'price': l10n.t('price'),
      'previous': l10n.t('previous'),
      'profile': l10n.t('profile'),
      'profile_edit_title': l10n.t('profile_edit_title'),
      'profile_phone_number': l10n.t('profile_phone_number'),
      'promociones': l10n.t('promociones'),
      'rating': l10n.t('rating'),
      'rating_title': l10n.t('rating_title'),
      'rating_all_reviews': l10n.t('rating_all_reviews'),
      'recojo': l10n.t('recojo'),
      'register': l10n.t('register'),
      'reservar': l10n.t('reservar'),
      'reservas': l10n.t('reservas'),
      'resolution': l10n.t('resolution'),
      'save': l10n.t('save'),
      'schedule': l10n.t('schedule'),
      'search': l10n.t('search'),
      'security': l10n.t('security'),
      'selectLanguage': l10n.t('selectLanguage'),
      'select_doc': l10n.t('select_doc'),
      'services': l10n.t('services'),
      'settings': l10n.t('settings'),
      'settings_options': l10n.t('settings_options'),
      'signIn': l10n.t('signIn'),
      'signUp': l10n.t('signUp'),
      'siguiente': l10n.t('siguiente'),
      'soporte': l10n.t('soporte'),
      'status': l10n.t('status'),
      'submit': l10n.t('submit'),
      'subtitle': l10n.t('subtitle'),
      'success': l10n.t('success'),
      'support': l10n.t('support'),
      'tableHeaders': l10n.t('tableHeaders'),
      'terms': l10n.t('terms'),
      'title': l10n.t('title'),
      'to': l10n.t('to'),
      'tracking': l10n.t('tracking'),
      'travelBoxGlobal': l10n.t('travelBoxGlobal'),
      'travelbox_logo_subtitle_compact': l10n.t('travelbox_logo_subtitle_compact'),
      'travelbox_tooltip': l10n.t('travelbox_tooltip'),
      'trip': l10n.t('trip'),
      'unverified': l10n.t('unverified'),
      'user': l10n.t('user'),
      'users': l10n.t('users'),
      'validated': l10n.t('validated'),
      'verify': l10n.t('verify'),
      'verifyEmail': l10n.t('verifyEmail'),
      'verifeCode': l10n.t('verifeCode'),
      'version': l10n.t('version'),
      'visibility': l10n.t('visibility'),
      'wallet': l10n.t('wallet'),
      'warehouse': l10n.t('warehouse'),
      'warehouses': l10n.t('warehouses'),
      'year': l10n.t('year'),
      'yes': l10n.t('yes'),
    };

    return translationsMap.keys.toList()..sort();
  }

  void _exportKeys(BuildContext context, List<String> keys, l10n) {
    final buffer = StringBuffer();
    for (final key in keys) {
      buffer.writeln('$key: ${l10n.t(key)}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Total keys exportadas: ${keys.length}'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Keys Exportadas'),
                content: SingleChildScrollView(
                  child: SelectableText(buffer.toString()),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}