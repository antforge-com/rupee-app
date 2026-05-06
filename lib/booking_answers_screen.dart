import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/question_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BookingAnswersScreen extends StatefulWidget {
  final int? bookingId;
  final int? specialBookingId;
  final String bookingType;
  final int? userId;
  final String clientName;

  const BookingAnswersScreen({
    super.key,
    this.bookingId,
    this.specialBookingId,
    this.bookingType = 'NORMAL',
    this.userId,
    required this.clientName,
  });

  @override
  State<BookingAnswersScreen> createState() => _BookingAnswersScreenState();
}

class _BookingAnswersScreenState extends State<BookingAnswersScreen> {
  final QuestionService _questionService = QuestionService();

  bool _loading = true;
  bool _usedUserFallback = false;
  String? _submittedAt;
  List<_AnswerItem> _answers = [];

  int? get _effectiveBookingId => widget.specialBookingId ?? widget.bookingId;

  String get _displayClientName {
    final raw = widget.clientName.trim();
    if (raw.isEmpty) return 'Client';
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _usedUserFallback = false;
    });

    try {
      final questionMap = await _loadQuestionMap();
      List<Map<String, dynamic>> bookingAnswers = [];

      if (widget.specialBookingId != null) {
        bookingAnswers = await _questionService.getAnswersForSpecialBooking(
          widget.specialBookingId!,
        );
      } else if (_effectiveBookingId != null) {
        bookingAnswers = await _questionService.getAnswersForBooking(
          widget.userId,
          _effectiveBookingId!,
          type: widget.bookingType,
        );
      }

      var normalized = _normalizeRows(bookingAnswers, questionMap);
      var usedFallback = false;

      if (normalized.isEmpty && widget.userId != null) {
        final userAnswers = await _questionService.getUserAnswers(widget.userId!);
        normalized = _normalizeRows(userAnswers, questionMap);
        usedFallback = normalized.isNotEmpty;
      }

      if (mounted) {
        setState(() {
          _answers = normalized;
          _usedUserFallback = usedFallback;
          _submittedAt = _extractSubmittedAt(bookingAnswers);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _answers = [];
          _loading = false;
        });
      }
    }
  }

  Future<Map<int, String>> _loadQuestionMap() async {
    final rows = await _questionService.getAllQuestions();
    final map = <int, String>{};
    for (final row in rows) {
      final id = _toInt(row['id'] ?? row['questionId']);
      final text = _string(
        row['text'] ?? row['questionText'] ?? row['question'],
      );
      if (id != null && text.isNotEmpty) {
        map[id] = text;
      }
    }
    return map;
  }

  List<_AnswerItem> _normalizeRows(
    List<Map<String, dynamic>> rows,
    Map<int, String> questionMap,
  ) {
    final items = <_AnswerItem>[];
    final seen = <String>{};

    void addAnswer({
      int? questionId,
      required String questionText,
      required String answer,
      String? type,
    }) {
      final cleanQuestion = questionText.trim();
      final cleanAnswer = answer.trim();
      if (cleanQuestion.isEmpty || cleanAnswer.isEmpty) return;

      final key = '${questionId ?? 0}|$cleanQuestion|$cleanAnswer';
      if (!seen.add(key)) return;

      items.add(
        _AnswerItem(
          questionId: questionId,
          questionText: cleanQuestion,
          answer: cleanAnswer,
          type: (type ?? 'text').toLowerCase(),
        ),
      );
    }

    for (final row in rows) {
      final nestedAnswers = row['answers'];
      if (nestedAnswers is List) {
        for (final nested in nestedAnswers.whereType<Map>()) {
          final map = Map<String, dynamic>.from(nested);
          final questionId = _toInt(map['questionId'] ?? map['question_id'] ?? map['id']);
          addAnswer(
            questionId: questionId,
            questionText: _resolveQuestionText(map, questionMap, questionId),
            answer: _resolveAnswerText(map),
            type: _string(map['type'] ?? map['questionType']),
          );
        }
        continue;
      }

      final questionId = _toInt(row['questionId'] ?? row['question_id'] ?? row['id']);
      final questionText = _resolveQuestionText(row, questionMap, questionId);
      final answerText = _resolveAnswerText(row);

      if (questionText.isNotEmpty && answerText.isNotEmpty) {
        addAnswer(
          questionId: questionId,
          questionText: questionText,
          answer: answerText,
          type: _string(row['type'] ?? row['questionType']),
        );
        continue;
      }

      final mapAnswer = row['answers'];
      if (mapAnswer is Map) {
        for (final entry in mapAnswer.entries) {
          addAnswer(
            questionText: entry.key.toString(),
            answer: _string(entry.value),
          );
        }
      }
    }

    items.sort((a, b) => a.questionText.compareTo(b.questionText));
    return items;
  }

  String _resolveQuestionText(
    Map<String, dynamic> row,
    Map<int, String> questionMap,
    int? questionId,
  ) {
    final direct = _string(
      row['questionText'] ??
          row['question_text'] ??
          row['text'] ??
          row['label'] ??
          (row['question'] is Map
              ? (row['question'] as Map)['text'] ?? (row['question'] as Map)['questionText']
              : null),
    );
    if (direct.isNotEmpty) return direct;
    if (questionId != null && questionMap.containsKey(questionId)) {
      return questionMap[questionId]!;
    }
    return questionId != null ? 'Question $questionId' : '';
  }

  String _resolveAnswerText(Map<String, dynamic> row) {
    final direct = row['answer'] ??
        row['answerText'] ??
        row['text'] ??
        row['response'] ??
        row['value'] ??
        row['selectedOption'] ??
        row['selected_option'];

    if (direct is List) {
      return direct.map((e) => _string(e)).where((e) => e.isNotEmpty).join(', ');
    }

    final selectedOptions = row['selectedOptions'] ?? row['selected_options'];
    if (selectedOptions is List) {
      return selectedOptions
          .map((e) => _string(e))
          .where((e) => e.isNotEmpty)
          .join(', ');
    }

    final text = _string(direct);
    if (text.contains('|||')) {
      return text.split('|||').map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
    }
    return text;
  }

  String? _extractSubmittedAt(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final candidate = _string(
        row['submittedAt'] ?? row['updatedAt'] ?? row['createdAt'],
      );
      if (candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _string(dynamic value) => (value ?? '').toString().trim();

  String _formatSubmittedAt(String value) {
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(value).toLocal());
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Client Answers',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _answers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 14),
                      if (_usedUserFallback) _buildFallbackBanner(),
                      if (_usedUserFallback) const SizedBox(height: 14),
                      ..._answers.map(_buildAnswerCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final bookingLabel = widget.specialBookingId != null ? 'Special Booking' : 'Booking';
    final bookingId = _effectiveBookingId?.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), AppColors.brandBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-Session Client Profile',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFA5F3FC),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _displayClientName,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$bookingLabel #$bookingId • ${widget.bookingType}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
          if ((_submittedAt ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Submitted ${_formatSubmittedAt(_submittedAt!)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.68),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Booking-specific answers were not found. Showing the client\'s latest saved answers instead.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(_AnswerItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForType(item.type),
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.questionText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.answer,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'mobile':
        return Icons.phone_rounded;
      case 'radio':
        return Icons.radio_button_checked_rounded;
      case 'multiselect':
        return Icons.checklist_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 34,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No answers yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This client has not submitted any pre-session answers for this booking.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerItem {
  final int? questionId;
  final String questionText;
  final String answer;
  final String type;

  const _AnswerItem({
    this.questionId,
    required this.questionText,
    required this.answer,
    required this.type,
  });
}
