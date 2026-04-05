import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/utils/app_error.dart';
import '../data/referral_repository.dart';

class ReferralPage extends ConsumerStatefulWidget {
  const ReferralPage({super.key});

  @override
  ConsumerState<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends ConsumerState<ReferralPage> {
  String? _myCode;
  String? _walletBalance;
  int _totalReferred = 0;
  bool _loading = true;
  String? _error;

  final _redeemController = TextEditingController();
  bool _redeeming = false;
  String? _redeemMessage;
  bool? _redeemSuccess;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  @override
  void dispose() {
    _redeemController.dispose();
    super.dispose();
  }

  Future<void> _loadMyCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(referralRepositoryProvider);
      final data = await repo.getMyReferralCode();
      setState(() {
        _myCode = data['code'] as String?;
        _walletBalance = data['walletBalance']?.toString();
        _totalReferred = (data['totalReferred'] as int?) ?? 0;
        _loading = false;
      });
    } on AppException catch (e) {
      if (e.statusCode == 404) {
        setState(() {
          _myCode = null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = e.error.backendMessage ?? e.toString();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generateCode() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(referralRepositoryProvider);
      final data = await repo.generateReferralCode();
      setState(() {
        _myCode = data['code'] as String?;
        _walletBalance = data['walletBalance']?.toString();
        _loading = false;
      });
    } on AppException catch (e) {
      setState(() {
        _error = e.error.backendMessage ?? e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _redeemCode() async {
    final code = _redeemController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _redeeming = true;
      _redeemMessage = null;
      _redeemSuccess = null;
    });
    try {
      final repo = ref.read(referralRepositoryProvider);
      final data = await repo.redeemReferralCode(code);
      setState(() {
        _redeemMessage = data['message'] as String? ??
            context.l10n.t('referral_redeemed_ok');
        _redeemSuccess = true;
        _redeeming = false;
        _redeemController.clear();
      });
      _loadMyCode();
    } on AppException catch (e) {
      setState(() {
        _redeemMessage = e.error.backendMessage ?? e.toString();
        _redeemSuccess = false;
        _redeeming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responsive = context.responsive;

    return AppShellScaffold(
      title: l10n.t('referrals'),
      currentRoute: '/referral',
      child: ListView(
        padding: responsive.pageInsets(
          top: responsive.verticalPadding,
          bottom: 24,
        ),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    size: 48,
                    color: TravelBoxBrand.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('referral_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('referral_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // My code section
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadMyCode,
                      child: Text(l10n.t('retry')),
                    ),
                  ],
                ),
              ),
            )
          else if (_myCode == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.t('referral_no_code'),
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.t('referral_generate')),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // My referral code card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.t('referral_your_code'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _myCode!,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _myCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.t('referral_copied')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                          label: l10n.t('referral_friends'),
                          value: '$_totalReferred',
                        ),
                        _StatChip(
                          label: l10n.t('referral_wallet'),
                          value: 'S/ ${_walletBalance ?? '0.00'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Redeem section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('referral_redeem_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _redeemController,
                          decoration: InputDecoration(
                            hintText: l10n.t('referral_redeem_hint'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _redeeming ? null : _redeemCode,
                        child: _redeeming
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.t('referral_redeem_btn')),
                      ),
                    ],
                  ),
                  if (_redeemMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _redeemMessage!,
                      style: TextStyle(
                        color: _redeemSuccess == true ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: TravelBoxBrand.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
