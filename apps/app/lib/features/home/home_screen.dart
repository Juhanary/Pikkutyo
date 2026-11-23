import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/provider_result.dart';
import '../../data/search_repository.dart';
import '../../data/work_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/ui.dart';

/// Koti: tervehdys, iso kysymys ja hakukortti. Kortissa vaihdetaan asiakkaan
/// haun (Etsi tekijä) ja tekijän ilmoituksen (Tarjoa työtä) välillä.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _mode = 0;
  WorkType _work = WorkType.tireChange;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

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

  void _search() {
    context.push(Uri(path: '/search', queryParameters: {
      'service': _work.code,
      'date': isoDate(_date),
    }).toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = _firstName(ref.watch(sessionProvider).valueOrNull?.user
        .userMetadata?['name']);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, bottomBarClearance),
          children: [
            Text(
              name == null ? t.homeGreeting : t.homeGreetingName(name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                t.homeTitle,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PillTabs(
                    labels: [t.modeFind, t.modeOffer],
                    selected: _mode,
                    onChanged: (i) => setState(() => _mode = i),
                  ),
                  const SizedBox(height: 16),
                  if (_mode == 0) _findForm(t) else _offerInfo(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _findForm(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, work) in WorkType.values.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _WorkChip(
                  icon: _workIcon(work),
                  label: _workLabel(t, work),
                  note: work.available ? null : t.comingSoon,
                  selected: work == _work,
                  onTap: work.available
                      ? () => setState(() => _work = work)
                      : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              label: Text(_dateLabel(t)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: Text(t.searchButton),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _offerInfo(AppLocalizations t) {
    final theme = Theme.of(context);
    final steps = [t.offerStep1, t.offerStep2, t.offerStep3];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.offerLead),
        const SizedBox(height: 12),
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.10),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          t.offerComingSoon,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _dateLabel(AppLocalizations t) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = _date.difference(today).inDays;
    if (days == 0) return t.dateToday;
    if (days == 1) return t.dateTomorrow;
    return MaterialLocalizations.of(context).formatShortMonthDay(_date);
  }
}

String? _firstName(Object? name) {
  if (name is! String || name.trim().isEmpty) return null;
  return name.trim().split(RegExp(r'\s+')).first;
}

IconData _workIcon(WorkType work) => switch (work) {
      WorkType.tireChange => Icons.tire_repair,
      WorkType.snowWork => Icons.ac_unit,
    };

String _workLabel(AppLocalizations t, WorkType work) => switch (work) {
      WorkType.tireChange => t.workTire,
      WorkType.snowWork => t.workSnow,
    };

/// Työlajin valintaruutu. Ruutu ilman `onTap`ia on pois käytöstä.
class _WorkChip extends StatelessWidget {
  const _WorkChip({
    required this.icon,
    required this.label,
    required this.selected,
    this.note,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? note;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = selected
        ? scheme.primary
        : enabled
            ? scheme.onSurface
            : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: controlBorderRadius,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: controlBorderRadius,
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        if (note != null)
                          Text(
                            note!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
