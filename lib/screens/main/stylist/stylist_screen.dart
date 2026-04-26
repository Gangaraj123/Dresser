import 'dart:convert';
import 'dart:math' show sin, cos;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../models/chat_message.dart';
import '../../../models/garment.dart';
import '../../../providers/garment_provider.dart';
import '../../../providers/outfit_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../theme/app_theme.dart';
import '../profile/profile_screen.dart';
import 'outfit_preview_screen.dart';

// ── Occasion data ─────────────────────────────────────────────────────────────

class _Occasion {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> whereOptions;
  final List<String> vibeOptions;
  const _Occasion({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.whereOptions,
    required this.vibeOptions,
  });
}

const _kOccasions = [
  _Occasion(
    label: 'Work',
    subtitle: 'Office & meetings',
    icon: Icons.work_outline_rounded,
    whereOptions: ['Office', 'Client meeting', 'Conference', 'WFH'],
    vibeOptions: ['Professional', 'Business casual', 'Creative'],
  ),
  _Occasion(
    label: 'Date Night',
    subtitle: 'Dinner & drinks',
    icon: Icons.favorite_outline_rounded,
    whereOptions: ['Restaurant', 'Rooftop bar', 'Café', 'Movies'],
    vibeOptions: ['Casual chic', 'Smart casual', 'Dressed up'],
  ),
  _Occasion(
    label: 'Wedding',
    subtitle: 'Guest attire',
    icon: Icons.celebration_outlined,
    whereOptions: ['Outdoor', 'Indoor', 'Beach', 'Garden'],
    vibeOptions: ['Formal', 'Smart casual', 'Summer'],
  ),
  _Occasion(
    label: 'Casual',
    subtitle: 'Weekend vibes',
    icon: Icons.wb_sunny_outlined,
    whereOptions: ['Park', 'Brunch', 'Mall', "Friend's place"],
    vibeOptions: ['Minimal', 'Streetwear', 'Cozy', 'Trendy'],
  ),
];

const _kMoreOccasions = ['Party', 'Interview', 'Vacation', 'Gym', 'Festival'];
const _kGenericWhereOptions = ['Indoors', 'Outdoors', 'Mixed venue'];
const _kGenericVibeOptions = ['Casual', 'Smart casual', 'Formal', 'Trendy'];

// ── View state ────────────────────────────────────────────────────────────────

enum _StylistView { home, refine, generating, results }

class _RecentLook {
  final ChatOutfitSuggestion suggestion;
  final String contextLabel;
  const _RecentLook({required this.suggestion, required this.contextLabel});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class StylistScreen extends ConsumerStatefulWidget {
  const StylistScreen({super.key});

  @override
  ConsumerState<StylistScreen> createState() => _StylistScreenState();
}

class _StylistScreenState extends ConsumerState<StylistScreen> {
  _StylistView _view = _StylistView.home;

  _Occasion? _selectedOccasion;
  String? _selectedOccasionCustom;
  String? _selectedWhere;
  String? _selectedVibe;
  final _customController = TextEditingController();
  final _quickAskController = TextEditingController();

  List<ChatOutfitSuggestion> _suggestions = [];
  String _eventSummary = '';
  int _resultIndex = 0;
  final _pageController = PageController();
  String? _generatingError;

  final List<_RecentLook> _recentLooks = [];

  @override
  void dispose() {
    _customController.dispose();
    _quickAskController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String get _occasionLabel =>
      _selectedOccasionCustom ?? _selectedOccasion?.label ?? '';

  List<String> get _whereOptions =>
      _selectedOccasion?.whereOptions ?? _kGenericWhereOptions;

  List<String> get _vibeOptions =>
      _selectedOccasion?.vibeOptions ?? _kGenericVibeOptions;

  void _selectOccasion(_Occasion occ) {
    setState(() {
      _selectedOccasion = occ;
      _selectedOccasionCustom = null;
      _selectedWhere = null;
      _selectedVibe = null;
      _customController.clear();
      _generatingError = null;
      _view = _StylistView.refine;
    });
  }

  void _selectMoreOccasion(String label) {
    setState(() {
      _selectedOccasion = null;
      _selectedOccasionCustom = label;
      _selectedWhere = null;
      _selectedVibe = null;
      _customController.clear();
      _generatingError = null;
      _view = _StylistView.refine;
    });
  }

  Future<void> _generate() async {
    setState(() {
      _view = _StylistView.generating;
      _generatingError = null;
    });
    final parts = <String>['Style me for $_occasionLabel'];
    if (_selectedWhere != null) parts.add('Location: $_selectedWhere');
    if (_selectedVibe != null) parts.add('Vibe: $_selectedVibe');
    final extra = _customController.text.trim();
    if (extra.isNotEmpty) parts.add(extra);
    await _callStylist(parts.join('. '));
  }

  Future<void> _quickAsk() async {
    final text = _quickAskController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedOccasion = null;
      _selectedOccasionCustom = null;
      _view = _StylistView.generating;
      _generatingError = null;
    });
    _quickAskController.clear();
    await _callStylist(text);
  }

  Future<void> _callStylist(String message) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/stylist/chat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message, 'conversation_history': []}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
        final reply = (data['reply'] as String?) ?? '';
        final rawSuggestions = data['outfit_suggestions'] as List?;
        final suggestions = rawSuggestions
                ?.map((s) =>
                    ChatOutfitSuggestion.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];

        if (suggestions.isEmpty) {
          setState(() {
            _generatingError = reply.isNotEmpty
                ? reply
                : "No suitable outfits found for this occasion. Try adjusting the vibe or adding more garments to your wardrobe.";
            _view = _StylistView.refine;
          });
          return;
        }

        // Save first result to recent looks
        final ctxLabel = _occasionLabel.isNotEmpty ? _occasionLabel : 'Custom';
        _recentLooks.insert(
            0, _RecentLook(suggestion: suggestions.first, contextLabel: ctxLabel));
        if (_recentLooks.length > 3) _recentLooks.removeLast();

        setState(() {
          _suggestions = suggestions;
          _eventSummary = reply;
          _resultIndex = 0;
          _view = _StylistView.results;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) _pageController.jumpToPage(0);
        });
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>?;
        final errMsg = body?['error']?['message'] as String?;
        setState(() {
          _generatingError = errMsg?.isNotEmpty == true
              ? errMsg!
              : 'Something went wrong. Please try again.';
          _view = _StylistView.refine;
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('SocketException') ||
              e.toString().contains('Connection')
          ? 'Could not connect. Check your connection and try again.'
          : 'Something went wrong. Please try again.';
      setState(() {
        _generatingError = msg;
        _view = _StylistView.refine;
      });
    }
  }

  void _goHome() => setState(() {
        _view = _StylistView.home;
        _generatingError = null;
      });

  @override
  Widget build(BuildContext context) {
    final garmentMap = ref.watch(garmentMapProvider);
    final profileAsync = ref.watch(profileProvider);
    final missingColorProfile = profileAsync.valueOrNull != null &&
        profileAsync.valueOrNull!['seasonal_type'] == null;

    return SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (_view) {
          _StylistView.home => _HomeView(
              key: const ValueKey('home'),
              quickAskController: _quickAskController,
              recentLooks: _recentLooks,
              garmentMap: garmentMap,
              missingColorProfile: missingColorProfile,
              onQuickAsk: _quickAsk,
              onOccasion: _selectOccasion,
              onMoreOccasion: _selectMoreOccasion,
            ),
          _StylistView.refine => _RefineView(
              key: const ValueKey('refine'),
              occasionLabel: _occasionLabel,
              whereOptions: _whereOptions,
              vibeOptions: _vibeOptions,
              selectedWhere: _selectedWhere,
              selectedVibe: _selectedVibe,
              customController: _customController,
              error: _generatingError,
              onBack: _goHome,
              onWhereSelected: (v) => setState(() => _selectedWhere = v),
              onVibeSelected: (v) => setState(() => _selectedVibe = v),
              onGenerate: _generate,
            ),
          _StylistView.generating => _GeneratingView(
              key: const ValueKey('generating'),
              occasionLabel: _occasionLabel,
            ),
          _StylistView.results => _ResultsView(
              key: const ValueKey('results'),
              occasionLabel: _occasionLabel,
              contextLabel: [
                _selectedWhere,
                _selectedVibe,
              ].whereType<String>().join(' · '),
              eventSummary: _eventSummary,
              suggestions: _suggestions,
              garmentMap: garmentMap,
              pageController: _pageController,
              currentIndex: _resultIndex,
              onPageChanged: (i) => setState(() => _resultIndex = i),
              onBack: _goHome,
              onSaved: () => ref.invalidate(outfitListProvider),
            ),
        },
      ),
    );
  }
}

// ── Home view ─────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  final TextEditingController quickAskController;
  final List<_RecentLook> recentLooks;
  final Map<String, Garment> garmentMap;
  final bool missingColorProfile;
  final VoidCallback onQuickAsk;
  final void Function(_Occasion) onOccasion;
  final void Function(String) onMoreOccasion;

  const _HomeView({
    super.key,
    required this.quickAskController,
    required this.recentLooks,
    required this.garmentMap,
    required this.missingColorProfile,
    required this.onQuickAsk,
    required this.onOccasion,
    required this.onMoreOccasion,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.textPrimary,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Stylist',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What are we dressing for today?',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Quick ask bar ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Icon(Icons.auto_awesome, size: 15, color: c.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: quickAskController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: '"Style me for a beach wedding..."',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary, fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => onQuickAsk(),
                  ),
                ),
                GestureDetector(
                  onTap: onQuickAsk,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Color profile nudge ──────────────────────────────────────────
          if (missingColorProfile) ...[
            _StylistColorNudge(),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 12),

          // ── Occasion grid ────────────────────────────────────────────────
          Text(
            'Style me for...',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: _kOccasions
                .map((occ) => _OccasionTile(occ: occ, onTap: () => onOccasion(occ)))
                .toList(),
          ),
          const SizedBox(height: 16),

          // ── More occasions ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kMoreOccasions.map((label) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onMoreOccasion(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Recent looks ─────────────────────────────────────────────────
          if (recentLooks.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Recent looks',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            const SizedBox(height: 12),
            ...recentLooks.map((look) => _RecentLookRow(
                  look: look,
                  garmentMap: garmentMap,
                )),
          ],
        ],
      ),
    );
  }
}

// ── Occasion tile ─────────────────────────────────────────────────────────────

class _OccasionTile extends StatelessWidget {
  final _Occasion occ;
  final VoidCallback onTap;
  const _OccasionTile({required this.occ, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Icon(occ.icon, size: 17, color: c.textPrimary),
            ),
            const Spacer(),
            Text(
              occ.label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              occ.subtitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent look row ───────────────────────────────────────────────────────────

class _RecentLookRow extends StatelessWidget {
  final _RecentLook look;
  final Map<String, Garment> garmentMap;
  const _RecentLookRow({required this.look, required this.garmentMap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final thumbs = look.suggestion.garmentIds
        .take(3)
        .map((id) => garmentMap[id])
        .map((g) => g?.thumbnailUrl ?? g?.displayImageUrl)
        .toList();
    final score = look.suggestion.matchScore;
    final scoreColor = score >= 85 ? c.sage : score >= 65 ? c.gold : c.blush;
    final scoreBg = score >= 85 ? c.sageLight : score >= 65 ? c.goldLight : c.blushLight;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OutfitPreviewScreen(suggestion: look.suggestion),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Row(
          children: [
            Row(
              children: thumbs.map((url) {
                return Container(
                  width: 42,
                  height: 52,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: url != null
                      ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                      : Icon(Icons.checkroom_outlined, size: 16, color: c.textTertiary),
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    look.suggestion.name,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    look.contextLabel,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreBg,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$score%',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w700, color: scoreColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Refine view ───────────────────────────────────────────────────────────────

class _RefineView extends StatelessWidget {
  final String occasionLabel;
  final List<String> whereOptions;
  final List<String> vibeOptions;
  final String? selectedWhere;
  final String? selectedVibe;
  final TextEditingController customController;
  final String? error;
  final VoidCallback onBack;
  final void Function(String) onWhereSelected;
  final void Function(String) onVibeSelected;
  final VoidCallback onGenerate;

  const _RefineView({
    super.key,
    required this.occasionLabel,
    required this.whereOptions,
    required this.vibeOptions,
    required this.selectedWhere,
    required this.selectedVibe,
    required this.customController,
    required this.error,
    required this.onBack,
    required this.onWhereSelected,
    required this.onVibeSelected,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back + title ──────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                occasionLabel,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 26, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Structured inputs ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TELL ME MORE',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: c.textTertiary, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),

                // Where?
                Text('Where?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: whereOptions.map((opt) {
                    final selected = selectedWhere == opt;
                    return GestureDetector(
                      onTap: () => onWhereSelected(opt),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? c.textPrimary : c.card,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: selected ? c.textPrimary : c.border, width: 1),
                        ),
                        child: Text(
                          opt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : c.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Vibe?
                Text('Vibe?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: vibeOptions.map((opt) {
                    final selected = selectedVibe == opt;
                    return GestureDetector(
                      onTap: () => onVibeSelected(opt),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? c.textPrimary : c.card,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: selected ? c.textPrimary : c.border, width: 1),
                        ),
                        child: Text(
                          opt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : c.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Anything else?
                Text('Anything else?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: TextField(
                    controller: customController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'First date, want to impress...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.blushLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.blush),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.blush),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onGenerate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: c.textPrimary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Style me',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generating view ───────────────────────────────────────────────────────────

class _GeneratingView extends StatefulWidget {
  final String occasionLabel;
  const _GeneratingView({super.key, required this.occasionLabel});

  @override
  State<_GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<_GeneratingView>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _phraseController;
  late Animation<double> _pulse;
  late Animation<double> _phraseFade;

  int _phraseIndex = 0;

  static const _phrases = [
    'Analysing your wardrobe...',
    'Matching colours and tones...',
    'Checking occasion fit...',
    'Balancing formality...',
    'Putting the look together...',
  ];

  static const _orbitItems = [
    (icon: Icons.checkroom_outlined,       angle: 0.0),
    (icon: Icons.dry_cleaning_outlined,    angle: 72.0),
    (icon: Icons.watch_outlined,           angle: 144.0),
    (icon: Icons.snowshoeing_outlined,     angle: 216.0),
    (icon: Icons.airline_seat_legroom_normal_outlined, angle: 288.0),
  ];

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _phraseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _phraseFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _phraseController, curve: Curves.easeIn),
    );
    _phraseController.forward();
    _cyclePhrases();
  }

  void _cyclePhrases() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _phraseController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
        _phraseController.forward();
        _cyclePhrases();
      });
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final label = widget.occasionLabel.isNotEmpty
        ? widget.occasionLabel
        : 'your occasion';
    const orbitRadius = 80.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Orbit animation ──────────────────────────────────────────────
            SizedBox(
              width: (orbitRadius + 24) * 2,
              height: (orbitRadius + 24) * 2,
              child: AnimatedBuilder(
                animation: _orbitController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centre pulsing sparkle
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.textPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.textPrimary.withValues(alpha: 0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),

                      // Orbiting garment icons
                      for (final item in _orbitItems) ...[
                        _OrbitIcon(
                          angle: item.angle,
                          orbitRadius: orbitRadius,
                          progress: _orbitController.value,
                          icon: item.icon,
                          c: c,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 36),

            // ── Headline ─────────────────────────────────────────────────────
            Text(
              'Your perfect $label look',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            // ── Cycling phrase ───────────────────────────────────────────────
            SizedBox(
              height: 20,
              child: FadeTransition(
                opacity: _phraseFade,
                child: Text(
                  _phrases[_phraseIndex],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Animated dots ────────────────────────────────────────────────
            _AnimatedDots(controller: _orbitController, c: c),
          ],
        ),
      ),
    );
  }
}

class _OrbitIcon extends StatelessWidget {
  final double angle;
  final double orbitRadius;
  final double progress;
  final IconData icon;
  final DresserColors c;

  const _OrbitIcon({
    required this.angle,
    required this.orbitRadius,
    required this.progress,
    required this.icon,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final rad = (angle / 360 + progress) * 2 * 3.141592653589793;
    final dx = orbitRadius * cos(rad);
    final dy = orbitRadius * sin(rad);
    // Opacity: front of orbit = 1.0, back = 0.3
    final opacity = (sin(rad) * 0.35 + 0.65).clamp(0.3, 1.0);
    // Scale: front = 1.0, back = 0.72
    final scale = (sin(rad) * 0.14 + 0.86).clamp(0.72, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, size: 17, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  final DresserColors c;

  const _AnimatedDots({required this.controller, required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value - i * 0.15) % 1.0;
            final scale = (sin(phase * 2 * 3.141592653589793) * 0.4 + 0.6)
                .clamp(0.4, 1.0);
            final opacity = (sin(phase * 2 * 3.141592653589793) * 0.5 + 0.5)
                .clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final String occasionLabel;
  final String contextLabel;
  final String eventSummary;
  final List<ChatOutfitSuggestion> suggestions;
  final Map<String, Garment> garmentMap;
  final PageController pageController;
  final int currentIndex;
  final void Function(int) onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _ResultsView({
    super.key,
    required this.occasionLabel,
    required this.contextLabel,
    required this.eventSummary,
    required this.suggestions,
    required this.garmentMap,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occasionLabel.isNotEmpty ? occasionLabel : 'Your look',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 22, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    if (contextLabel.isNotEmpty)
                      Text(
                        contextLabel,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: c.textTertiary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Dot pagination ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(suggestions.length, (i) {
                final active = i == currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? c.textPrimary : c.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${currentIndex + 1} of ${suggestions.length}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary),
              ),
            ],
          ),
        ),

        // ── Outfit cards (swipeable) ────────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: suggestions.length,
            itemBuilder: (context, i) => _OutfitResultCard(
              suggestion: suggestions[i],
              garmentMap: garmentMap,
              onSaved: onSaved,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Outfit result card ────────────────────────────────────────────────────────

class _OutfitResultCard extends ConsumerStatefulWidget {
  final ChatOutfitSuggestion suggestion;
  final Map<String, Garment> garmentMap;
  final VoidCallback onSaved;

  const _OutfitResultCard({
    required this.suggestion,
    required this.garmentMap,
    required this.onSaved,
  });

  @override
  ConsumerState<_OutfitResultCard> createState() => _OutfitResultCardState();
}

class _OutfitResultCardState extends ConsumerState<_OutfitResultCard> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _saveOutfit() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/outfits'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': widget.suggestion.name,
          'garment_ids': widget.suggestion.garmentIds,
        }),
      );

      if (res.statusCode == 200) {
        widget.onSaved();
        setState(() => _saved = true);
      } else {
        throw Exception('Save failed (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final s = widget.suggestion;
    final score = s.matchScore;
    final scoreColor = score >= 85 ? c.sage : score >= 65 ? c.gold : c.blush;
    final scoreBg = score >= 85 ? c.sageLight : score >= 65 ? c.goldLight : c.blushLight;

    final garments = s.garmentIds
        .map((id) => widget.garmentMap[id])
        .where((g) => g != null)
        .cast<Garment>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + score
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 24, fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                          Text(
                            '${garments.length} piece${garments.length == 1 ? '' : 's'} · All from your closet',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: scoreBg,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '$score%',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Garment images — large portrait tiles
                if (garments.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: garments.take(4).map((g) {
                        final url = g.displayImageUrl ?? g.thumbnailUrl;
                        final name = g.subCategory?.isNotEmpty == true
                            ? g.subCategory!
                            : g.category;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c.bg2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border, width: 1),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              children: [
                                if (url != null)
                                  Positioned.fill(
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, _) => Container(color: c.bg2),
                                      errorWidget: (ctx, e, s) => Center(
                                        child: Icon(Icons.checkroom_outlined,
                                            color: c.textTertiary, size: 22),
                                      ),
                                    ),
                                  )
                                else
                                  Center(
                                    child: Icon(Icons.checkroom_outlined,
                                        color: c.textTertiary, size: 22),
                                  ),
                                // Item label at bottom
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withValues(alpha: 0.0),
                                          Colors.black.withValues(alpha: 0.55),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    child: Text(
                                      _cap(name),
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Why this works
                if (s.reasoning.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 11, color: c.gold),
                            const SizedBox(width: 6),
                            Text(
                              'WHY THIS WORKS',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: c.gold,
                                  letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.reasoning,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: c.textSecondary, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Action buttons ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _saving ? null : _saveOutfit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _saved
                          ? c.sageLight
                          : c.textPrimary,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        else
                          Icon(
                            _saved ? Icons.check_rounded : Icons.bookmark_outline_rounded,
                            size: 16,
                            color: _saved ? c.sage : Colors.white,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _saved ? 'Saved' : 'Save outfit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _saved ? c.sage : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OutfitPreviewScreen(suggestion: s),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: c.border, width: 1),
                  ),
                  child: Text(
                    'Details',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ),

          // Swipe hint
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Swipe for more looks →',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Color profile nudge (stylist) ─────────────────────────────────────────────

class _StylistColorNudge extends StatelessWidget {
  const _StylistColorNudge();

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.palette_outlined, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add your color profile for better style matches',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: c.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Set up →',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

