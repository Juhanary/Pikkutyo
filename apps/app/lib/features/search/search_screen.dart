import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../data/provider_result.dart';
import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/ui.dart';

/// Hakutulokset päivälle ("lumityöntekijä huomiselle"). Tulokset näytetään
/// siinä järjestyksessä kuin palvelin ne antaa (ADR 0007).
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key, required this.serviceCode, this.date});

  final String serviceCode;

  /// Haettava päivä. `null` tarkoittaa tätä päivää.
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final day = DateUtils.dateOnly(date ?? DateTime.now());
    final query = (
      citySlug: AppConfig.defaultCitySlug,
      serviceCode: serviceCode,
      date: isoDate(day),
      locale: locale,
    );
    final results = ref.watch(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.searchTitle),
            Text(
              MaterialLocalizations.of(context).formatFullDate(day),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Padded(
          EmptyCard(
            text: t.searchError,
            action: TextButton(
              onPressed: () => ref.invalidate(searchResultsProvider(query)),
              child: Text(t.retry),
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? _Padded(EmptyCard(text: t.searchEmpty))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(searchResultsProvider(query).future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ProviderCard(item: items[i], locale: locale),
                ),
              ),
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [child],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.item, required this.locale});

  final ProviderResult item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final private = item.kind == ProviderKind.privatePerson;
    final rating = item.ratingAvg == null
        ? t.noRating
        : t.rating(item.ratingAvg!.toStringAsFixed(1), item.ratingCount);
    final details = [
      if (item.districtName != null) item.districtName!,
      rating,
    ].join(' · ');
    final initial = item.displayName.isEmpty
        ? '?'
        : item.displayName.characters.first.toUpperCase();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/book/${item.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.10),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _KindBadge(
                          label: private ? t.kindPrivate : t.kindCompany,
                          private: private,
                        ),
                        Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatEuros(item.priceCents + item.travelFeeCents, locale),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    t.freeSlots(item.freeSlots),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tekijän asema näkyy jokaisessa tuloksessa (suunnitelma: pelisäännöt).
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label, required this.private});

  final String label;
  final bool private;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = private ? scheme.primaryContainer : scheme.tertiaryContainer;
    final fg = private ? scheme.onPrimaryContainer : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
