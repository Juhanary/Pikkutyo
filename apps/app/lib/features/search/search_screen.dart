import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../data/provider_result.dart';
import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Haku päivälle ("lumityöntekijä huomiselle"). Tulokset näytetään siinä
/// järjestyksessä kuin palvelin ne antaa.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  // Kategoriat (lumityö, renkaanvaihto) tulevat askeleessa 1. Siihen asti
  // haetaan kannan nykyistä palvelua.
  static const _serviceCode = 'tire_change';

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final query = (
      citySlug: AppConfig.defaultCitySlug,
      serviceCode: _serviceCode,
      date: isoDate(_date),
      locale: locale,
    );
    final results = ref.watch(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(t.searchTitle)),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(t.searchDate),
            subtitle: Text(MaterialLocalizations.of(context).formatFullDate(_date)),
            onTap: _pickDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _Message(
                text: t.searchError,
                action: TextButton(
                  onPressed: () => ref.invalidate(searchResultsProvider(query)),
                  child: Text(t.retry),
                ),
              ),
              data: (items) => items.isEmpty
                  ? _Message(text: t.searchEmpty)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(searchResultsProvider(query).future),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _ProviderTile(item: items[i], locale: locale),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.item, required this.locale});

  final ProviderResult item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rating = item.ratingAvg == null
        ? t.noRating
        : t.rating(item.ratingAvg!.toStringAsFixed(1), item.ratingCount);
    final details = [
      item.kind == ProviderKind.privatePerson ? t.kindPrivate : t.kindCompany,
      if (item.districtName != null) item.districtName!,
      rating,
      t.freeSlots(item.freeSlots),
    ].join(' · ');

    return ListTile(
      title: Text(item.displayName),
      subtitle: Text(details),
      trailing: Text(
        formatEuros(item.priceCents + item.travelFeeCents, locale),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => context.push('/book/${item.slug}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
