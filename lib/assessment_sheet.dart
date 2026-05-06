import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/services.dart';

class AssessmentSheet extends StatefulWidget {
  final int bookingId;
  final String bookingType; // 'NORMAL' or 'SPECIAL'
  final int? consultantId;

  const AssessmentSheet({
    super.key,
    required this.bookingId,
    required this.bookingType,
    this.consultantId,
  });

  static Future<void> show(
    BuildContext context, {
    required int bookingId,
    required String bookingType,
    int? consultantId,
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AssessmentSheet(
        bookingId: bookingId,
        bookingType: bookingType,
        consultantId: consultantId,
      ),
    );
  }

  @override
  State<AssessmentSheet> createState() => _AssessmentSheetState();
}

class _AssessmentSheetState extends State<AssessmentSheet> {
  final _questionService = QuestionService();
  final _controllers = <int, TextEditingController>{};
  
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final qs = await _questionService.getAllQuestions();
      if (mounted) {
        setState(() {
          _questions = qs;
          for (var q in _questions) {
            _controllers[q['id']] = TextEditingController();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load assessment questions';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    
    final answers = _questions.map((q) => {
      'questionId': q['id'],
      'text': _controllers[q['id']]?.text ?? '',
    }).toList();

    final ok = await _questionService.submitAnswers(
      bookingId: widget.bookingId,
      bookingType: widget.bookingType,
      consultantId: widget.consultantId,
      answers: answers,
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you! Your assessment has been submitted.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit assessment. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pre-Session Assessment',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please answer these questions to help our expert prepare for your session.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final q = _questions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q['questionText'] ?? q['text'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _controllers[q['id']],
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Your answer...',
                                    hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Footer
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Submit Assessment',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
