// lib/features/bookings/booking_feedback_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// BOOKING FEEDBACK SCREEN — 100% backend-integrated
// ✔ Loads booking & consultant info dynamically
// ✔ Star rating (1-5) tappable UI
// ✔ Comments field (max 1000 chars)
// ✔ POST /api/feedbacks — submits with consultantId, meetingId, bookingId, rating
// ✔ Checks if feedback already exists for this booking
// ✔ Edit existing feedback via PUT /api/feedbacks/{id}
// ✔ Matches web design colour scheme (teal/dark)
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: use_build_context_synchronously

import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart' as models;
import 'package:finadvise/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _snack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: Duration(seconds: error ? 4 : 2),
    ));
}

String _fmtDate(dynamic d) {
  if (d == null || d.toString().isEmpty) return '—';
  try {
    return DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(d.toString()).toLocal());
  } catch (_) {
    return d.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════

class BookingFeedbackScreen extends StatefulWidget {
  final int bookingId;
  final int? meetingId;      // If known upfront; otherwise we resolve from booking
  final int? consultantId;   // If known upfront; otherwise we resolve from booking
  final String? consultantName;
  final String? bookingDate;

  const BookingFeedbackScreen({
    super.key,
    required this.bookingId,
    this.meetingId,
    this.consultantId,
    this.consultantName,
    this.bookingDate,
  });

  @override
  State<BookingFeedbackScreen> createState() => _BookingFeedbackScreenState();
}

class _BookingFeedbackScreenState extends State<BookingFeedbackScreen> {
  final _feedbackService = FeedbackService();
  final _dio = ApiClient().dio;
  final _commentsCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;

  // Resolved from booking if not provided upfront
  int? _resolvedConsultantId;
  int? _resolvedMeetingId;
  String _consultantName = '';
  String _bookingDateStr = '';
  String _bookingStatus = '';

  // Existing feedback (if any)
  models.Feedback? _existingFeedback;
  int? _existingFeedbackId;

  int _rating = 0;       // 1-5; 0 = not yet selected
  int _hoverRating = 0;  // for hover effect on desktop (unused on mobile)

  final List<String> _ratingLabels = const [
    '',
    'Poor',
    'Fair',
    'Good',
    'Very Good',
    'Excellent',
  ];

  @override
  void initState() {
    super.initState();
    _resolvedConsultantId = widget.consultantId;
    _resolvedMeetingId = widget.meetingId;
    _consultantName = widget.consultantName ?? '';
    _bookingDateStr = widget.bookingDate ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _commentsCtrl.dispose();
    super.dispose();
  }

  // ─── Load booking + existing feedback ───────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1. Load booking details to get consultantId, meetingId etc.
      await _loadBookingDetails();

      // 2. Check if feedback already exists for this booking
      await _loadExistingFeedback();
    } catch (e) {
      // If everything fails, we still show the form with whatever we have
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBookingDetails() async {
    try {
      final response = await _dio.get('/api/bookings/${widget.bookingId}');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;

      // Extract consultant
      if (_resolvedConsultantId == null) {
        _resolvedConsultantId =
            data['consultantId'] ?? data['consultant']?['id'];
      }
      if (_consultantName.isEmpty) {
        _consultantName = data['consultantName'] ??
            data['consultant']?['name'] ??
            data['consultant']?['fullName'] ??
            '';
      }

      // Extract meeting
      if (_resolvedMeetingId == null) {
        _resolvedMeetingId =
            data['meetingId'] ?? data['meeting']?['id'];
      }

      // Booking date and status
      if (_bookingDateStr.isEmpty) {
        _bookingDateStr = (data['bookingDate'] ??
                data['scheduledAt'] ??
                data['date'] ??
                '')
            .toString();
      }
      _bookingStatus = (data['status'] ?? '').toString();
    } catch (_) {}
  }

  Future<void> _loadExistingFeedback() async {
    try {
      final existing = await _feedbackService.getFeedbackByBooking(widget.bookingId);
      if (existing != null && mounted) {
        setState(() {
          _existingFeedback = existing;
          _existingFeedbackId = existing.id;
          _rating = existing.rating.clamp(1, 5);
          _commentsCtrl.text = existing.comments ?? '';
        });
      }
    } catch (_) {}
  }

  // ─── Submit / Update feedback ────────────────────────────────────────────

  Future<void> _submit() async {
    if (_rating == 0) {
      _snack(context, 'Please select a star rating', error: true);
      return;
    }
    if (_resolvedConsultantId == null) {
      _snack(context, 'Could not resolve consultant. Please try again.', error: true);
      return;
    }
    if (_resolvedMeetingId == null) {
      _snack(context, 'Could not resolve meeting. Please try again.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final comments = _commentsCtrl.text.trim();

      if (_existingFeedbackId != null) {
        // UPDATE existing
        final ok = await _feedbackService.updateFeedback(
          _existingFeedbackId!,
          rating: _rating,
          comments: comments.isEmpty ? null : comments,
        );
        if (ok) {
          _snack(context, 'Feedback updated successfully!');
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        } else {
          _snack(context, 'Failed to update feedback', error: true);
        }
      } else {
        // CREATE new
        final result = await _feedbackService.submitFeedback(
          consultantId: _resolvedConsultantId!,
          meetingId: _resolvedMeetingId!,
          bookingId: widget.bookingId,
          rating: _rating,
          comments: comments.isEmpty ? null : comments,
        );
        if (result != null) {
          _snack(context, 'Feedback submitted! Thank you.');
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        } else {
          _snack(context, 'Failed to submit feedback', error: true);
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Rate Your Session',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Booking summary card ─────────────────────────────
                  _buildBookingCard(),
                  const SizedBox(height: 20),

                  // ── Existing feedback notice ─────────────────────────
                  if (_existingFeedback != null) _buildEditNotice(),
                  if (_existingFeedback != null) const SizedBox(height: 14),

                  // ── Star rating ──────────────────────────────────────
                  _buildRatingSection(),
                  const SizedBox(height: 20),

                  // ── Comments ─────────────────────────────────────────
                  _buildCommentsSection(),
                  const SizedBox(height: 28),

                  // ── Submit button ────────────────────────────────────
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ─── Booking card ─────────────────────────────────────────────────────────

  Widget _buildBookingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_note_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Booking #${widget.bookingId}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              if (_bookingDateStr.isNotEmpty)
                Text(
                  _fmtDate(_bookingDateStr),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
            ]),
          ),
          if (_bookingStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Text(
                _bookingStatus,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
              ),
            ),
        ]),
        if (_consultantName.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                _consultantName.isNotEmpty ? _consultantName[0].toUpperCase() : 'C',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _consultantName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Text('Your Consultant', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ],
      ]),
    );
  }

  // ─── Edit notice ──────────────────────────────────────────────────────────

  Widget _buildEditNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You\'ve already submitted feedback. You can update it below.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  // ─── Star rating ──────────────────────────────────────────────────────────

  Widget _buildRatingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        const Text(
          'How was your session?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your feedback helps us improve our service',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 20),

        // Stars row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled = starIndex <= _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 44,
                    color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),

        // Rating label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _rating > 0 ? _ratingLabels[_rating] : 'Tap a star to rate',
            key: ValueKey(_rating),
            style: TextStyle(
              fontSize: 15,
              fontWeight: _rating > 0 ? FontWeight.w700 : FontWeight.w400,
              color: _rating > 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Rating scale hint
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('1 — Poor', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            Text('3 — Good', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
            Text('5 — Excellent', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
          ],
        ),
      ]),
    );
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Share your thoughts',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional — max 1000 characters',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _commentsCtrl,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: 'Tell us about your experience with the consultant…',
            hintStyle: const TextStyle(color: Color(0xFFBBBBC8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        // Quick rating chips
        const SizedBox(height: 12),
        const Text('Quick tags:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _buildQuickTags(),
        ),
      ]),
    );
  }

  List<Widget> _buildQuickTags() {
    final tags = [
      'Very helpful',
      'Clear explanation',
      'Professional',
      'On time',
      'Great advice',
      'Would recommend',
    ];
    return tags.map((tag) {
      final selected = _commentsCtrl.text.contains(tag);
      return GestureDetector(
        onTap: () {
          setState(() {
            final current = _commentsCtrl.text;
            if (selected) {
              _commentsCtrl.text = current.replaceAll(', $tag', '').replaceAll(tag, '').trim();
            } else {
              _commentsCtrl.text = current.isEmpty ? tag : '$current, $tag';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.primary : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ─── Submit button ────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final isEdit = _existingFeedbackId != null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isEdit ? Icons.update_rounded : Icons.send_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Update Feedback' : 'Submit Feedback',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ]),
      ),
    );
  }
}