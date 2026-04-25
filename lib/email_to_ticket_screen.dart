import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailToTicketScreen extends StatefulWidget {
  const EmailToTicketScreen({super.key});

  @override
  State<EmailToTicketScreen> createState() => _EmailToTicketScreenState();
}

class _EmailToTicketScreenState extends State<EmailToTicketScreen> {
  final _service = EmailToTicketService();
  bool _loading = true;
  bool _polling = false;
  String? _healthMessage;
  String? _lastActionMessage;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    setState(() => _loading = true);
    final health = await _service.getHealthStatus();
    if (!mounted) return;
    setState(() {
      _healthMessage = health ?? 'Unable to reach email-to-ticket health endpoint';
      _loading = false;
    });
  }

  Future<void> _triggerPoll() async {
    setState(() => _polling = true);
    final message = await _service.triggerPolling();
    if (!mounted) return;
    setState(() {
      _lastActionMessage = message ?? 'Email polling request failed';
      _polling = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_lastActionMessage!)),
    );
    await _loadHealth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Email Inbox',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHealth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Health',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _healthMessage ?? 'No status available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Poll',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Trigger backend email polling to convert incoming messages into tickets.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _polling ? null : _triggerPoll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _polling
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Trigger Email Polling',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        if ((_lastActionMessage ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _lastActionMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
