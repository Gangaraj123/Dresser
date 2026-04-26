import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/garment.dart';
import '../../../providers/garment_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chip_row.dart';
import '../../../widgets/garment_card.dart';
import '../../../widgets/stat_card.dart';
import 'add_garment_screen.dart';
import 'garment_detail_screen.dart';

class ClosetScreen extends ConsumerStatefulWidget {
  const ClosetScreen({super.key});

  @override
  ConsumerState<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends ConsumerState<ClosetScreen> {
  String _activeFilter = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _filters = ['All', 'Tops', 'Bottoms', 'Outerwear', 'Footwear', 'Accessories'];

  static const _filterToCategory = {
    'Tops': 'topwear',
    'Bottoms': 'bottomwear',
    'Outerwear': 'outerwear',
    'Footwear': 'footwear',
    'Accessories': 'accessory',
  };

  // Polls every 15s while any garment is still processing
  bool _pollingActive = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _maybeStartPolling(List<Garment> garments) {
    final anyProcessing = garments.any((g) => g.isProcessing);
    if (anyProcessing && !_pollingActive) {
      _pollingActive = true;
      Future.delayed(const Duration(seconds: 15), _pollProcessing);
    } else if (!anyProcessing) {
      _pollingActive = false;
    }
  }

  void _pollProcessing() {
    if (!mounted) return;
    ref.invalidate(garmentListProvider);
    final garments = ref.read(garmentListProvider).valueOrNull ?? [];
    if (garments.any((g) => g.isProcessing)) {
      Future.delayed(const Duration(seconds: 15), _pollProcessing);
    } else {
      _pollingActive = false;
    }
  }

  List<Garment> _applyFilters(List<Garment> garments) {
    var list = garments;
    if (_activeFilter != 'All') {
      final cat = _filterToCategory[_activeFilter];
      if (cat != null) list = list.where((g) => g.category == cat).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((g) {
        return (g.displayName.toLowerCase().contains(_searchQuery)) ||
            (g.brand?.toLowerCase().contains(_searchQuery) ?? false) ||
            (g.dominantColorName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (g.category.toLowerCase().contains(_searchQuery));
      }).toList();
    }
    return list;
  }

  Future<void> _openAddGarment() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddGarmentScreen()),
    );
    if (added == true) {
      ref.invalidate(garmentListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final garmentAsync = ref.watch(garmentListProvider);
    final stats = ref.watch(wardrobeStatsProvider).valueOrNull ?? WardrobeStats.empty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(garmentListProvider),
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
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'My Closet',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _openAddGarment,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      garmentAsync.isLoading
                          ? 'Loading...'
                          : '${stats.total} item${stats.total == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Stats row ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            value: '${stats.topwear}',
                            label: 'Tops',
                            valueColor: stats.topwear > 0 ? null : c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            value: '${stats.bottomwear}',
                            label: 'Bottoms',
                            valueColor: stats.bottomwear > 0 ? null : c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            value: '${stats.outerwear + stats.footwear + stats.accessory}',
                            label: 'Others',
                            valueColor: (stats.outerwear + stats.footwear + stats.accessory) > 0
                                ? null
                                : c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Search ───────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          Icon(Icons.search, size: 18, color: c.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: c.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search your wardrobe...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: c.textTertiary,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => _searchController.clear(),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Icon(Icons.close, size: 16, color: c.textTertiary),
                              ),
                            )
                          else
                            const SizedBox(width: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Filter chips ─────────────────────────────────────────
                    FilterChipRow(
                      filters: _filters,
                      activeFilter: _activeFilter,
                      onFilterChanged: (f) => setState(() => _activeFilter = f),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Grid / states ──────────────────────────────────────────────
            garmentAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: _ErrorState(
                  message: err.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(garmentListProvider),
                ),
              ),
              data: (garments) {
                // Start polling if any garment is still being enhanced
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _maybeStartPolling(garments));
                if (garments.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyCloset(onAdd: _openAddGarment),
                  );
                }
                final filtered = _applyFilters(garments);
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyFilter(
                      query: _searchQuery.isNotEmpty ? _searchQuery : _activeFilter,
                      onClear: () {
                        _searchController.clear();
                        setState(() => _activeFilter = 'All');
                      },
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final garment = filtered[index];
                        return GarmentCard(
                          garment: garment,
                          onTap: () async {
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => GarmentDetailScreen(garment: garment),
                              ),
                            );
                            if (changed == true) ref.invalidate(garmentListProvider);
                          },
                        );
                      },
                      childCount: filtered.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3 / 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyCloset extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCloset({required this.onAdd});

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
              child: Icon(Icons.checkroom_outlined, size: 32, color: c.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              'Your closet is empty',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first garment by taking a photo\nor uploading from your gallery.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: c.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Add your first item',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _EmptyFilter({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onClear,
              child: Text(
                'Clear filter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: c.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
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
              "Couldn't load your wardrobe",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Try again',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
