import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/discover_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../theme/app_theme.dart';
import '../profile/profile_screen.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dc;
    final insightsAsync = ref.watch(discoverInsightsProvider);
    final profileAsync = ref.watch(profileProvider);
    final missingColorProfile = profileAsync.valueOrNull != null &&
        profileAsync.valueOrNull!['seasonal_type'] == null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(discoverInsightsProvider),
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
                      'Discover',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wardrobe intelligence',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            if (missingColorProfile)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: _ColorProfileNudge(),
                ),
              ),

            if (insightsAsync.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (insightsAsync.hasError)
              SliverFillRemaining(
                child: _ErrorState(
                  message: insightsAsync.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(discoverInsightsProvider),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: _InsightsBody(insights: insightsAsync.value!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Insights body ─────────────────────────────────────────────────────────────

class _InsightsBody extends StatelessWidget {
  final DiscoverInsights insights;
  const _InsightsBody({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekly tip — always first
        if (insights.weeklyTip != null) ...[
          _WeeklyTipCard(tip: insights.weeklyTip!),
          const SizedBox(height: 24),
        ],

        // Color balance
        if (insights.colorBalance.breakdown.isNotEmpty) ...[
          _SectionHeader(title: 'Color balance'),
          const SizedBox(height: 12),
          _ColorBalanceCard(balance: insights.colorBalance),
          const SizedBox(height: 24),
        ],

        // Wardrobe gaps
        if (insights.gaps.isNotEmpty) ...[
          _SectionHeader(title: 'Wardrobe gaps'),
          const SizedBox(height: 12),
          ...insights.gaps.map((gap) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GapCard(gap: gap),
              )),
          const SizedBox(height: 14),
        ],

        // Forgotten items
        if (insights.forgottenItems.isNotEmpty) ...[
          _SectionHeader(title: 'Forgotten items'),
          const SizedBox(height: 4),
          Text(
            'Items you own but haven\'t worn recently',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: context.dc.textTertiary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: insights.forgottenItems.length,
              itemBuilder: (context, i) => _ForgottenItemCard(
                item: insights.forgottenItems[i],
                thumbnail: insights.garmentThumbnails[
                    insights.forgottenItems[i].garmentId],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Untried combinations
        if (insights.untriedCombinations.isNotEmpty) ...[
          _SectionHeader(title: 'Untried combinations'),
          const SizedBox(height: 4),
          Text(
            'Items you own but have never paired together',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: context.dc.textTertiary),
          ),
          const SizedBox(height: 12),
          ...insights.untriedCombinations.map((combo) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ComboCard(
                  combo: combo,
                  thumbnails: insights.garmentThumbnails,
                ),
              )),
        ],

        // Empty state
        if (insights.gaps.isEmpty &&
            insights.forgottenItems.isEmpty &&
            insights.untriedCombinations.isEmpty &&
            insights.weeklyTip == null)
          const _EmptyState(),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: context.dc.textPrimary,
      ),
    );
  }
}

// ── Weekly tip ────────────────────────────────────────────────────────────────

class _WeeklyTipCard extends StatelessWidget {
  final WeeklyTip tip;
  const _WeeklyTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 13, color: c.gold),
              const SizedBox(width: 6),
              Text(
                'WEEKLY TIP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: c.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tip.body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.6,
            ),
          ),
          if (tip.basedOn.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tip.basedOn,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Color balance ─────────────────────────────────────────────────────────────

class _ColorBalanceCard extends StatelessWidget {
  final ColorBalance balance;
  const _ColorBalanceCard({required this.balance});

  Color _familyColor(String family, bool dark) {
    switch (family.toLowerCase()) {
      case 'cool':
        return dark ? const Color(0xFF6B9BD2) : const Color(0xFF5B8DBE);
      case 'warm':
        return dark ? const Color(0xFFD4936A) : const Color(0xFFC4845A);
      case 'neutral':
        return dark ? const Color(0xFF9A9A9A) : const Color(0xFF8A8A8A);
      default:
        return dark ? const Color(0xFF777777) : const Color(0xFFAAAAAA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: balance.breakdown.map((entry) {
                  return Flexible(
                    flex: entry.percentage,
                    child: Container(color: _familyColor(entry.colorFamily, dark)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: balance.breakdown.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _familyColor(entry.colorFamily, dark),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_cap(entry.colorFamily)} ${entry.percentage}%',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: c.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
          // Recommendation
          if (balance.recommendation != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: c.border),
            const SizedBox(height: 12),
            Text(
              balance.recommendation!,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: c.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Gap card ──────────────────────────────────────────────────────────────────

class _GapCard extends StatelessWidget {
  final WardrobeGap gap;
  const _GapCard({required this.gap});

  Color _priorityColor(String p, DresserColors c) {
    switch (p) {
      case 'high':
        return c.blush;
      case 'medium':
        return c.gold;
      default:
        return c.textTertiary;
    }
  }

  Color _priorityBg(String p, DresserColors c) {
    switch (p) {
      case 'high':
        return c.blushLight;
      case 'medium':
        return c.goldLight;
      default:
        return c.bg2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final pColor = _priorityColor(gap.priority, c);
    final pBg = _priorityBg(gap.priority, c);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gap.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pBg,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  gap.priority,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w700, color: pColor),
                ),
              ),
            ],
          ),
          if (gap.action.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 13, color: c.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    gap.action,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          if (gap.outfitsUnlocked > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.sageLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unlocks ${gap.outfitsUnlocked} new outfit${gap.outfitsUnlocked == 1 ? '' : 's'}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w600, color: c.sage),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Forgotten item card ───────────────────────────────────────────────────────

class _ForgottenItemCard extends StatelessWidget {
  final ForgottenItem item;
  final String? thumbnail;
  const _ForgottenItemCard({required this.item, required this.thumbnail});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final label = item.subCategory?.isNotEmpty == true
        ? _cap(item.subCategory!)
        : _cap(item.category ?? 'Item');
    final daysLabel = item.daysSinceWorn != null
        ? '${item.daysSinceWorn}d ago'
        : item.timesWorn == 0
            ? 'Never worn'
            : 'Long ago';

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: thumbnail != null
                ? CachedNetworkImage(
                    imageUrl: thumbnail!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (ctx, _) => Container(color: c.bg2),
                    errorWidget: (ctx, e, s) => Container(
                      color: c.bg2,
                      child: Center(
                        child: Icon(Icons.checkroom_outlined,
                            color: c.textTertiary, size: 24),
                      ),
                    ),
                  )
                : Container(
                    color: c.bg2,
                    child: Center(
                      child: Icon(Icons.checkroom_outlined,
                          color: c.textTertiary, size: 24),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  daysLabel,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: c.blush),
                ),
                const SizedBox(height: 6),
                Text(
                  item.suggestion,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: c.textSecondary, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Untried combination card ──────────────────────────────────────────────────

class _ComboCard extends StatelessWidget {
  final UntriedCombo combo;
  final Map<String, String?> thumbnails;
  const _ComboCard({required this.combo, required this.thumbnails});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final thumbs = combo.garmentIds
        .take(4)
        .map((id) => thumbnails[id])
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        children: [
          // Thumbnails stacked
          SizedBox(
            width: thumbs.length * 44.0 - (thumbs.length - 1) * 10.0,
            height: 60,
            child: Stack(
              children: thumbs.asMap().entries.map((entry) {
                final i = entry.key;
                final url = entry.value;
                return Positioned(
                  left: i * 34.0,
                  child: Container(
                    width: 48,
                    height: 60,
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.card, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: url != null
                        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                        : Icon(Icons.checkroom_outlined,
                            color: c.textTertiary, size: 16),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (combo.occasion.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      combo.occasion,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: c.textTertiary),
                    ),
                  ),
                Text(
                  combo.reasoning,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: c.textSecondary, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              child: Icon(Icons.explore_outlined, size: 32, color: c.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing to discover yet',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Add more items to your closet and your\nwardrobe intelligence will appear here.',
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
            Text(
              "Couldn't load insights",
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: c.textTertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Try again',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color profile nudge ───────────────────────────────────────────────────────

class _ColorProfileNudge extends ConsumerWidget {
  const _ColorProfileNudge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dc;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.palette_outlined,
                  color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock color-aware styling',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Analyse your skin tone for personalised outfit recommendations',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.gold, size: 18),
          ],
        ),
      ),
    );
  }
}
