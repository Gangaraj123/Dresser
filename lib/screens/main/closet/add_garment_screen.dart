import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../../../config/supabase_config.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tag_chip.dart';

class AddGarmentScreen extends StatefulWidget {
  const AddGarmentScreen({super.key});

  @override
  State<AddGarmentScreen> createState() => _AddGarmentScreenState();
}

enum _UploadStep { idle, analyzing, extracting, processing, done, retake }

class _AddGarmentScreenState extends State<AddGarmentScreen> {
  File? _imageFile;
  Uint8List? _compressedBytes; // compressed bytes sent to backend
  _UploadStep _step = _UploadStep.idle;
  Map<String, dynamic>? _result;
  String? _error;
  String? _retakeTip;

  // Progress messages shown during the fast ingest phase
  static const _stepMessages = {
    _UploadStep.analyzing:   'Analyzing your photo…',
    _UploadStep.extracting:  'Reading garment details…',
    _UploadStep.processing:  'Almost done…',
  };

  late TextEditingController _subCatCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _subCatCtrl = TextEditingController();
    _brandCtrl  = TextEditingController();
    _noteCtrl   = TextEditingController();
  }

  @override
  void dispose() {
    _subCatCtrl.dispose();
    _brandCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _enhanceWithAI = true;   // user toggle: run Gemini image gen in background

  bool get _uploading =>
      _step == _UploadStep.analyzing ||
      _step == _UploadStep.extracting ||
      _step == _UploadStep.processing;

  // ── Pick image ──────────────────────────────────────────────────────────────

  /// Compress to 1024px max, JPEG 90% — visually lossless, ~150-300 KB.
  Future<Uint8List?> _compress(String filePath) async {
    return FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 90,
      format: CompressFormat.jpeg,
    );
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    // Pick without applying quality here — we compress explicitly below.
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final compressed = await _compress(picked.path);
    if (compressed == null) return;

    setState(() {
      _imageFile = File(picked.path); // original file used only for preview
      _compressedBytes = compressed;
      _result = null;
      _error = null;
    });
    await _upload();
  }

  void _showPickerSheet() {
    final c = context.dc;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.bg3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: c.textPrimary),
              title: Text('Take a photo',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: c.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.textPrimary),
              title: Text('Choose from gallery',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: c.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Upload to backend ────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_imageFile == null || _compressedBytes == null) return;
    setState(() {
      _step = _UploadStep.analyzing;
      _error = null;
      _retakeTip = null;
      _result = null;
    });

    // Advance progress messages during the fast ingest (~3–6s total)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _step == _UploadStep.analyzing) {
        setState(() => _step = _UploadStep.extracting);
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _step == _UploadStep.extracting) {
        setState(() => _step = _UploadStep.processing);
      }
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      // Send compressed bytes directly — no need to read from disk again.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/garments'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          _compressedBytes!,
          filename: 'garment.jpg',
        ));

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final envelope = json.decode(body) as Map<String, dynamic>;

      if (streamed.statusCode == 200) {
        final data = envelope['data'] as Map<String, dynamic>;
        final analysis = data['_photo_analysis'] as Map<String, dynamic>?;
        setState(() {
          _result = data;
          _step = _UploadStep.done;
          _subCatCtrl.text = (data['sub_category'] as String?) ?? '';
          _brandCtrl.text  = (data['brand'] as String?) ?? '';
          // Surface a tip if lighting was poor but we still processed it
          if (analysis?['retake_tip'] != null) {
            _retakeTip = analysis!['retake_tip'] as String;
          }
        });
      } else if (streamed.statusCode == 422) {
        // Quality gate — garment not visible
        final errMsg = envelope['error']?['message'] as String? ??
            'No garment detected. Try a clearer photo.';
        setState(() {
          _step = _UploadStep.retake;
          _retakeTip = errMsg;
        });
      } else {
        final errMsg = envelope['error']?['message'] as String? ??
            'Upload failed (HTTP ${streamed.statusCode})';
        setState(() {
          _step = _UploadStep.idle;
          _error = errMsg;
        });
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _step = _UploadStep.idle;
        _error = msg;
      });
    }
  }

  // ── Save (patch notes/brand/sub_category) ───────────────────────────────────

  Future<void> _save() async {
    if (_result == null) return;
    setState(() => _step = _UploadStep.processing);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken;
      final garmentId = _result!['id'] as String;
      final base = '${SupabaseConfig.apiBaseUrl}/api/v1/garments/$garmentId';

      // 1. Save metadata edits
      await http.put(
        Uri.parse(base),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (_subCatCtrl.text.isNotEmpty)
            'sub_category': _subCatCtrl.text.trim(),
          if (_brandCtrl.text.isNotEmpty) 'brand': _brandCtrl.text.trim(),
          if (_noteCtrl.text.isNotEmpty) 'notes': _noteCtrl.text.trim(),
        }),
      );

      // 2. Trigger background enhancement (fire-and-forget)
      final skip = !_enhanceWithAI;
      http.post(
        Uri.parse('$base/enhance?skip=$skip'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _step = _UploadStep.done;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back,
                          size: 18, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Add garment',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Take or upload a photo — AI does the rest',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary),
                    ),
                    const SizedBox(height: 20),

                    // ── Photo area ──
                    _PhotoArea(
                      imageFile: _imageFile,
                      step: _step,
                      result: _result,
                      stepMessages: _stepMessages,
                      onTap: _uploading ? null : _showPickerSheet,
                    ),

                    // ── Retake prompt ──
                    if (_step == _UploadStep.retake && _retakeTip != null) ...[
                      const SizedBox(height: 14),
                      _RetakeCard(tip: _retakeTip!, onRetake: _showPickerSheet, c: c),
                    ],

                    // ── Soft quality tip (processed but not perfect) ──
                    if (_step == _UploadStep.done && _retakeTip != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _retakeTip!,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Error ──
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.blush.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.blush.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.blush, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.blush)),
                            ),
                            GestureDetector(
                              onTap: _upload,
                              child: Text('Retry',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.blush)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Enhancing notice ──
                    if (_step == _UploadStep.done && _result != null &&
                        (_result!['thumbnail_url'] == null)) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.sage.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                color: AppColors.sage,
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Photo is being enhanced in the background — '
                                'your wardrobe will update automatically.',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.sage,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── AI results ──
                    if (_step == _UploadStep.done && _result != null) ...[
                      const SizedBox(height: 24),
                      _TagsSection(result: _result!, c: c),
                      const SizedBox(height: 20),
                      _EditableField(
                        label: 'Sub-category',
                        controller: _subCatCtrl,
                        hint: 'e.g. oxford shirt, slim jeans',
                        c: c,
                      ),
                      const SizedBox(height: 12),
                      _EditableField(
                        label: 'Brand (optional)',
                        controller: _brandCtrl,
                        hint: 'e.g. Uniqlo, Zara',
                        c: c,
                      ),
                      const SizedBox(height: 12),
                      _EditableField(
                        label: 'Notes (optional)',
                        controller: _noteCtrl,
                        hint: 'e.g. Gift from mum, bought in Tokyo',
                        c: c,
                        maxLines: 2,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Enhance toggle ──
                    if (_step == _UploadStep.done && _result != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _enhanceWithAI = !_enhanceWithAI),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.bg2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_fix_high_outlined,
                                  size: 18,
                                  color: _enhanceWithAI
                                      ? AppColors.sage
                                      : c.textTertiary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enhance photo with AI',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _enhanceWithAI
                                          ? 'Gemini will press and clean the photo in background'
                                          : 'Keep original photo as-is',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: c.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _enhanceWithAI,
                                onChanged: (v) =>
                                    setState(() => _enhanceWithAI = v),
                                activeThumbColor: AppColors.sage,
                                activeTrackColor: AppColors.sageLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Save button ──
                    if (_step == _UploadStep.done && _result != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploading ? null : _save,
                          child: _uploading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Save to wardrobe'),
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo area ───────────────────────���─────────────────────────��─────────────

class _PhotoArea extends StatelessWidget {
  final File? imageFile;
  final _UploadStep step;
  final Map<String, dynamic>? result;
  final Map<_UploadStep, String> stepMessages;
  final VoidCallback? onTap;

  const _PhotoArea({
    required this.imageFile,
    required this.step,
    required this.result,
    required this.stepMessages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final h = MediaQuery.of(context).size.height * 0.28;

    // Show processed product image once done
    final displayUrl = result?['display_image_url'] as String?;
    final bool uploading = step == _UploadStep.analyzing ||
        step == _UploadStep.extracting ||
        step == _UploadStep.processing;

    Widget content;

    if (step == _UploadStep.retake) {
      // Show original photo dimmed — retake card is shown below
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (imageFile != null)
            Image.file(imageFile!, fit: BoxFit.cover)
          else
            Container(color: c.bg2),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          Center(
            child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 36),
          ),
        ],
      );
    } else if (step == _UploadStep.done && displayUrl != null) {
      // Show AI-processed product image
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(displayUrl, fit: BoxFit.contain),
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Change',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      );
    } else if (imageFile != null) {
      // Uploading — show original with overlay
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(imageFile!, fit: BoxFit.cover),
          if (uploading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      stepMessages[step] ?? 'Processing…',
                      key: ValueKey(step),
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      // Empty — prompt to pick
      content = GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(accentColor: c.textPrimary),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.bg2, shape: BoxShape.circle),
                child: Icon(Icons.camera_alt_outlined, color: c.textPrimary, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Take or upload photo',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text('Wearing it or flat-lay — AI handles both',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textTertiary)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: (uploading || step == _UploadStep.done) ? null : onTap,
      child: Container(
        width: double.infinity,
        height: h,
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.hardEdge,
        child: content,
      ),
    );
  }
}

// ── Retake card ────────────────────────────────────��───────────────────────���──

class _RetakeCard extends StatelessWidget {
  final String tip;
  final VoidCallback onRetake;
  final DresserColors c;

  const _RetakeCard({required this.tip, required this.onRetake, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blush.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blush.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: AppColors.blush, size: 16),
              const SizedBox(width: 8),
              Text('Photo needs improvement',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blush)),
            ],
          ),
          const SizedBox(height: 8),
          Text(tip,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetake,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blush,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text('Try again',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tags section ────────────────────────────────���─────────────────────────��──

class _TagsSection extends StatelessWidget {
  final Map<String, dynamic> result;
  final DresserColors c;

  const _TagsSection({required this.result, required this.c});

  @override
  Widget build(BuildContext context) {
    final subCat = (result['sub_category'] as String?) ?? 'Item';
    final category = (result['category'] as String?) ?? '';
    final confidence = ((result['ai_confidence'] as num?) ?? 0) * 100;
    final pattern = result['pattern'] as String?;
    final fabric = result['fabric'] as String?;
    final formalityScore = result['formality_score'] as int?;
    final seasons = (result['season_suitability'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    final dominantHex = result['dominant_color_hex'] as String?;
    final dominantName = result['dominant_color_name'] as String?;
    final displayUrl = result['display_image_url'] as String?;

    Color? dotColor;
    if (dominantHex != null) {
      try {
        dotColor = Color(
            int.parse('FF${dominantHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AI-detected tags',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${confidence.toStringAsFixed(0)}% confidence',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: displayUrl != null
                        ? Image.network(displayUrl,
                            width: 56, height: 70, fit: BoxFit.cover)
                        : Container(
                            width: 56,
                            height: 70,
                            color: c.bg2,
                            child: Icon(Icons.checkroom_outlined,
                                color: c.textTertiary, size: 28),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalise(subCat),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _capitalise(category),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                children: [
                  if (category.isNotEmpty)
                    TagChip(
                        label: _capitalise(category),
                        type: TagType.category),
                  if (dominantName != null && dotColor != null)
                    TagChip(
                        label: _capitalise(dominantName),
                        type: TagType.color,
                        dotColor: dotColor),
                  if (seasons.isNotEmpty)
                    TagChip(
                        label: seasons.length == 4
                            ? 'All season'
                            : seasons.map(_capitalise).join(', '),
                        type: TagType.season),
                  if (formalityScore != null)
                    TagChip(
                        label: 'Formality $formalityScore/5',
                        type: TagType.formality),
                  if (fabric != null && fabric != 'null')
                    TagChip(
                        label: _capitalise(fabric), type: TagType.fabric),
                  if (pattern != null &&
                      pattern != 'null' &&
                      pattern != 'none')
                    TagChip(
                        label: _capitalise(pattern),
                        type: TagType.pattern),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Editable field ────────────────────────────────────────────────────────────

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final DresserColors c;
  final int maxLines;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.c,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: c.textTertiary),
            filled: true,
            fillColor: c.bg2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color accentColor;

  _DashedBorderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dashWidth), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
