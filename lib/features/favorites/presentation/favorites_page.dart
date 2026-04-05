import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/utils/app_error.dart';
import '../data/favorites_repository.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  List<FavoriteWarehouse>? _favorites;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      final favs = await repo.list();
      if (mounted) setState(() { _favorites = favs; _loading = false; });
    } on AppException catch (e) {
      if (mounted) setState(() { _error = e.error.backendMessage ?? e.toString(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _removeFromFavorites(FavoriteWarehouse fav) async {
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      await repo.remove(fav.warehouseId);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responsive = context.responsive;

    return AppShellScaffold(
      title: l10n.t('favorites'),
      currentRoute: '/favorites',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: Text(l10n.t('retry'))),
                    ],
                  ),
                )
              : _favorites == null || _favorites!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('favorites_empty'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('favorites_empty_hint'),
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: responsive.pageInsets(top: responsive.verticalPadding, bottom: 24),
                        itemCount: _favorites!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final fav = _favorites![index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.warehouse_outlined),
                              title: Text(fav.warehouseName),
                              subtitle: Text('${fav.cityName} • ${fav.warehouseAddress}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () => _removeFromFavorites(fav),
                              ),
                              onTap: () => context.push('/warehouse/${fav.warehouseId}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
