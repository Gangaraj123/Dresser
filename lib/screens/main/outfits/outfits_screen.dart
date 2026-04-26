import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/outfit.dart';
import '../../../providers/garment_provider.dart';
import '../../../providers/outfit_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/outfit_card.dart';
import 'outfit_detail_screen.dart';

class OutfitsScreen extends ConsumerStatefulWidget {
  const OutfitsScreen({super.key});

  @override
  ConsumerState<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends ConsumerState<OutfitsScreen> {
  late int _calMonth;
  late int _calYear;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _dayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calMonth = now.month - 1;
    _calYear = now.year;
  }

  List<String?> _thumbnailsFor(Outfit outfit, Map<String, String?> thumbnailMap) =>
      outfit.garmentIds.map((id) => thumbnailMap[id]).toList();

  Set<int> _wornDays(List<Outfit> outfits) {
    final days = <int>{};
    for (final o in outfits) {
      if (o.lastWornDate == null) continue;
      final d = DateTime.tryParse(o.lastWornDate!);
      if (d != null && d.month - 1 == _calMonth && d.year == _calYear) {
        days.add(d.day);
      }
    }
    return days;
  }

  List<int?> _calendarDays(int month, int year) {
    final firstDay = DateTime(year, month + 1, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(year, month + 1);
    final days = <int?>[
      ...List.filled(startOffset, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final outfitAsync = ref.watch(outfitListProvider);
    // Derive thumbnail map from the shared garment provider (no extra fetch)
    final garments = ref.watch(garmentListProvider).valueOrNull ?? [];
    final thumbnailMap = {
      for (final g in garments) g.id: g.thumbnailUrl ?? g.displayImageUrl,
    };

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(outfitListProvider),
        color: c.textPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Outfits',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outfitAsync.isLoading
                          ? 'Loading…'
                          : '${outfitAsync.valueOrNull?.length ?? 0} look${(outfitAsync.valueOrNull?.length ?? 0) == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            if (outfitAsync.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (outfitAsync.hasError)
              SliverFillRemaining(
                child: _ErrorState(
                  message: outfitAsync.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(outfitListProvider),
                ),
              )
            else if ((outfitAsync.valueOrNull ?? []).isEmpty)
              const SliverFillRemaining(child: _EmptyOutfits())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final outfit = outfitAsync.value![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutfitCard(
                          outfit: outfit,
                          thumbnails: _thumbnailsFor(outfit, thumbnailMap),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  OutfitDetailScreen(outfit: outfit),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: outfitAsync.value!.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: _WearCalendar(
                    month: _calMonth,
                    year: _calYear,
                    wornDays: _wornDays(outfitAsync.value!),
                    monthNames: _monthNames,
                    dayHeaders: _dayHeaders,
                    calendarDays: _calendarDays(_calMonth, _calYear),
                    today: DateTime.now(),
                    onPrev: () => setState(() {
                      if (_calMonth > 0) {
                        _calMonth--;
                      } else {
                        _calMonth = 11;
                        _calYear--;
                      }
                    }),
                    onNext: () => setState(() {
                      if (_calMonth < 11) {
                        _calMonth++;
                      } else {
                        _calMonth = 0;
                        _calYear++;
                      }
                    }),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Wear calendar widget ──────────────────────────────────────────────────────

class _WearCalendar extends StatelessWidget {
  final int month;
  final int year;
  final Set<int> wornDays;
  final List<String> monthNames;
  final List<String> dayHeaders;
  final List<int?> calendarDays;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WearCalendar({
    required this.month,
    required this.year,
    required this.wornDays,
    required this.monthNames,
    required this.dayHeaders,
    required this.calendarDays,
    required this.today,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wear calendar',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onPrev,
                    child: Icon(Icons.chevron_left, color: c.textSecondary, size: 22),
                  ),
                  Text(
                    '${monthNames[month]} $year',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  GestureDetector(
                    onTap: onNext,
                    child: Icon(Icons.chevron_right, color: c.textSecondary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: dayHeaders
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: c.textTertiary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              ...List.generate((calendarDays.length / 7).ceil(), (rowIndex) {
                final start = rowIndex * 7;
                final end = (start + 7).clamp(0, calendarDays.length);
                final weekDays = calendarDays.sublist(start, end);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: weekDays.map((day) {
                      if (day == null) return const Expanded(child: SizedBox());
                      final hasOutfit = wornDays.contains(day);
                      final isToday = day == today.day &&
                          month == today.month - 1 &&
                          year == today.year;

                      return Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasOutfit ? c.bg2 : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isToday
                                    ? Border.all(color: c.textPrimary, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: (hasOutfit || isToday)
                                        ? c.textPrimary
                                        : c.textSecondary,
                                    fontWeight: (hasOutfit || isToday)
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyOutfits extends StatelessWidget {
  const _EmptyOutfits();

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.bg2, shape: BoxShape.circle),
              child: Icon(Icons.style_outlined, size: 32, color: c.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              'No saved outfits yet',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat with your AI stylist to get outfit\nsuggestions saved to your wardrobe.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: c.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: c.textTertiary),
            const SizedBox(height: 16),
            Text("Couldn't load outfits",
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                    color: AppColors.textPrimary, borderRadius: BorderRadius.circular(50)),
                child: Text('Try again',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
