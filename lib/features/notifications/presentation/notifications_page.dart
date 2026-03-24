import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/notification_center_controller.dart';
import '../../../shared/utils/status_localizer.dart';
import '../domain/app_notification.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationCenterControllerProvider.notifier).markAllSeen();
      ref.read(notificationCenterControllerProvider.notifier).refreshNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationCenterControllerProvider);

    return AppShellScaffold(
      title: context.l10n.t('notifications'),
      currentRoute: '/notifications',
      actions: [
        TextButton.icon(
          onPressed: notifications.items.isEmpty
              ? null
              : _clearAllNotifications,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(context.l10n.t('eliminar_todo')),
        ),
        TextButton.icon(
          onPressed: notifications.items.isEmpty
              ? null
              : () => ref
                    .read(notificationCenterControllerProvider.notifier)
                    .markAllSeen(),
          icon: Icon(Icons.done_all_outlined),
          label: Text(context.l10n.t('marcar_leidas')),
        ),
      ],
      child: _buildBody(context, notifications),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationCenterState notifications,
  ) {
    if (notifications.loading && notifications.items.isEmpty) {
      return LoadingStateView();
    }

    if (notifications.errorKey != null && notifications.items.isEmpty) {
      return ErrorStateView(
        message: context.l10n.t(notifications.errorKey!),
        onRetry: () => ref
            .read(notificationCenterControllerProvider.notifier)
            .refreshNow(),
      );
    }

    if (notifications.items.isEmpty) {
      return EmptyStateView(message: context.l10n.t('notifications_empty'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(notificationCenterControllerProvider.notifier)
            .refreshNow();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _UnreadSummary(unreadCount: notifications.unreadCount);
          }
          final item = notifications.items[index - 1];
          final isUnread = !notifications.seenIds.contains(item.id);
          return _NotificationCard(
            notification: item,
            isUnread: isUnread,
            onTap: () {
              ref
                  .read(notificationCenterControllerProvider.notifier)
                  .markSeen(item.id);
              final route = item.route;
              if (route != null && route.isNotEmpty) {
                context.push(route);
              }
            },
            onDelete: () => _deleteNotification(item),
          );
        },
      ),
    );
  }

  Future<void> _deleteNotification(AppNotification item) async {
    await ref
        .read(notificationCenterControllerProvider.notifier)
        .deleteNotification(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('notificacion_eliminada'))),
    );
  }

  Future<void> _clearAllNotifications() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('eliminar_notificaciones')),
        content: Text(context.l10n.t('notifications_clear_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('eliminar_todo')),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await ref
        .read(notificationCenterControllerProvider.notifier)
        .clearAllNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('notificaciones_eliminadas'))),
    );
  }
}

class _UnreadSummary extends StatelessWidget {
  const _UnreadSummary({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5FAFF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                unreadCount <= 0
                    ? context.l10n.t('notifications_unread_none')
                    : '${context.l10n.t('notifications_unread_prefix')} '
                          '$unreadCount '
                          '${context.l10n.t('notifications_unread_suffix')}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isUnread,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool isUnread;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isUnread ? const Color(0xFFEFF8FF) : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isUnread
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${notification.message}\n'
          '${notification.whenLabel} - '
          '${notificationStatusLabel(context, notification.status)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: context.l10n.t('settings_options'),
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(context.l10n.t('eliminar')),
            ),
          ],
        ),
      ),
    );
  }
}
