import 'package:finadvise/app_theme.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:finadvise/services/services.dart';
import 'package:finadvise/shared/ticket_number_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailToTicketScreen extends StatefulWidget {
  const EmailToTicketScreen({
    super.key,
    this.readOnly,
    this.allowDirectTicketCreation = false,
  });
  final bool? readOnly;
  final bool allowDirectTicketCreation;

  @override
  State<EmailToTicketScreen> createState() => _EmailToTicketScreenState();
}

class _ComposeSupportResult {
  final bool emailOpened;
  final String? ticketNo;

  const _ComposeSupportResult._({
    required this.emailOpened,
    this.ticketNo,
  });

  const _ComposeSupportResult.emailOpened()
      : this._(
          emailOpened: true,
          ticketNo: null,
        );

  const _ComposeSupportResult.ticketCreated(String ticketNo)
      : this._(
          emailOpened: false,
          ticketNo: ticketNo,
        );
}

class _EmailToTicketScreenState extends State<EmailToTicketScreen> {
  final _service = EmailToTicketService();
  final _ticketService = TicketService();
  final _authService = AuthService();

  bool _loading = true;
  bool _polling = false;
  bool _canManageInbox = false;
  String? _healthMessage;
  String? _lastActionMessage;
  String _mailbox = 'support@meetthemasters.in';
  List<String> _ticketCategories = const [];
  static const List<String> _composePriorities = [
    'LOW',
    'MEDIUM',
    'HIGH',
    'URGENT',
    'CRITICAL',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final explicitReadOnly = widget.readOnly;
    final resolvedReadOnly = explicitReadOnly ?? await _resolveReadOnlyByRole();
    if (!mounted) return;
    _canManageInbox = !resolvedReadOnly;
    if (_canManageInbox) {
      await _loadHealth();
      return;
    }
    setState(() {
      _healthMessage =
          'Send your support request to $_mailbox and a ticket will be created automatically.';
      _loading = false;
    });
  }

  Future<bool> _resolveReadOnlyByRole() async {
    final role = (await _authService.getUserRole() ?? '').toUpperCase();
    final normalized = role.replaceAll('ROLE_', '');
    final hasAdminInboxAccess = normalized == 'ADMIN' ||
        normalized == 'SUPER_ADMIN' ||
        normalized == 'MASTER_ADMIN' ||
        normalized == 'ROOT';
    return !hasAdminInboxAccess;
  }

  Future<void> _loadHealth() async {
    setState(() => _loading = true);
    final health = await _service.getHealthStatus();
    if (!mounted) return;
    final mailMatch = RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ).firstMatch(health.message);
    if (mailMatch != null && mailMatch.group(0) != null) {
      _mailbox = mailMatch.group(0)!.trim();
    }
    final isPermissionDenied =
        !health.ok && _isPermissionDeniedMessage(health.message);
    if (isPermissionDenied) {
      setState(() {
        _canManageInbox = false;
        _healthMessage =
            'Send your support request to $_mailbox and a ticket will be created automatically.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _healthMessage = health.message;
      _loading = false;
    });
  }

  Future<void> _triggerPoll() async {
    if (!_canManageInbox) return;
    setState(() => _polling = true);
    final result = await _service.triggerPolling();
    if (!mounted) return;
    final isPermissionDenied =
        !result.ok && _isPermissionDeniedMessage(result.message);
    if (isPermissionDenied) {
      setState(() {
        _canManageInbox = false;
        _lastActionMessage =
            'Manual polling is allowed only for admin operators.';
        _polling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Manual polling is allowed only for admin operators.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final pollingTimedOut =
        !result.ok && _isPollingTimeoutMessage(result.message);
    if (!result.ok && !pollingTimedOut) {
      setState(() => _polling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (pollingTimedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Polling request timed out, but processing may continue in background. Refreshing status now.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    setState(() {
      _lastActionMessage = pollingTimedOut
          ? 'Polling started. It may take longer than expected to complete.'
          : result.message;
      _polling = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lastActionMessage!),
        backgroundColor: AppColors.success,
      ),
    );
    if (_canManageInbox) {
      await _loadHealth();
    }
  }

  bool _isPermissionDeniedMessage(String message) {
    final value = message.toLowerCase();
    return value.contains('permission') ||
        value.contains('forbidden') ||
        value.contains('unauthorized') ||
        value.contains('not authorized') ||
        value.contains('access denied') ||
        value.contains('403');
  }

  bool _isPollingTimeoutMessage(String message) {
    final value = message.toLowerCase();
    return value.contains('timed out') ||
        value.contains('timeout') ||
        value.contains('receive timeout') ||
        value.contains('send timeout') ||
        value.contains('connection timeout') ||
        value.contains('socket');
  }

  Future<List<String>> _ensureTicketCategories() async {
    if (_ticketCategories.isNotEmpty) return _ticketCategories;
    try {
      final categories = await _ticketService.getUniqueCategories();
      final normalized = categories
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      if (normalized.isEmpty) {
        normalized.add('General');
      }
      if (mounted) {
        setState(() => _ticketCategories = normalized);
      } else {
        _ticketCategories = normalized;
      }
      return normalized;
    } catch (_) {
      const fallback = ['General'];
      if (mounted) {
        setState(() => _ticketCategories = fallback);
      } else {
        _ticketCategories = fallback;
      }
      return fallback;
    }
  }

  Future<bool> _launchSupportEmail({
    required String subject,
    String? body,
  }) async {
    final query = <String, String>{};
    final trimmedSubject = subject.trim();
    final trimmedBody = body?.trim() ?? '';
    if (trimmedSubject.isNotEmpty) query['subject'] = trimmedSubject;
    if (trimmedBody.isNotEmpty) query['body'] = trimmedBody;

    final encodedQuery = query.isEmpty
        ? null
        : query.entries
            .map((entry) =>
                '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
            .join('&');
    final uri = Uri(
      scheme: 'mailto',
      path: _mailbox,
      query: encodedQuery,
    );

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _composeSupportEmail() async {
    final allowDirectCreation = widget.allowDirectTicketCreation;
    final categories =
        allowDirectCreation ? await _ensureTicketCategories() : ['General'];
    if (!mounted) return;

    final userId = allowDirectCreation
        ? int.tryParse(await _authService.getUserId() ?? '')
        : null;
    if (!mounted) return;
    final subjectCtrl = TextEditingController(text: 'Support Request');
    final bodyCtrl = TextEditingController(
      text: allowDirectCreation
          ? ''
          : 'Hi Support Team,\n\n'
              'I need help with:\n\n'
              '- Issue:\n'
              '- Steps to reproduce:\n'
              '- Expected result:\n'
              '- Actual result:\n\n'
              'Thanks,',
    );
    String selectedCategory = categories.first;
    String selectedPriority = 'MEDIUM';
    bool creatingTicket = false;
    bool composingSheetClosed = false;

    try {
      final composeResult = await showDialog<_ComposeSupportResult>(
        context: context,
        barrierDismissible: true,
        useRootNavigator: true,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> closeComposerSheetIfOpen([
                _ComposeSupportResult? result,
              ]) async {
                if (composingSheetClosed) return;
                composingSheetClosed = true;
                if (!sheetContext.mounted) return;
                await Navigator.of(
                  sheetContext,
                  rootNavigator: true,
                ).maybePop(result);
              }

              Future<void> openEmailApp() async {
                final subject = subjectCtrl.text.trim().isEmpty
                    ? 'Support Request'
                    : subjectCtrl.text.trim();
                final launched = await _launchSupportEmail(
                  subject: subject,
                  body: bodyCtrl.text.trim(),
                );
                if (!mounted) return;
                if (!launched) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to open email app right now.',
                      ),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                await closeComposerSheetIfOpen(
                  const _ComposeSupportResult.emailOpened(),
                );
              }

              Future<void> createTicketNow() async {
                if (!allowDirectCreation) return;
                if (creatingTicket) return;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Session expired. Please login again to create ticket.',
                      ),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                final description = bodyCtrl.text.trim();
                if (description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your issue details'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                if (composingSheetClosed || !sheetContext.mounted) return;
                setSheetState(() => creatingTicket = true);
                final subject = subjectCtrl.text.trim();
                final ticketDescription = subject.isEmpty
                    ? description
                    : 'Subject: $subject\n\n$description';
                final ticket = await _ticketService.createTicket(
                  userId: userId,
                  category: selectedCategory,
                  description: ticketDescription,
                  priority: selectedPriority,
                );
                if (!mounted) return;

                if (!composingSheetClosed && sheetContext.mounted) {
                  setSheetState(() => creatingTicket = false);
                }

                if (ticket == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Unable to create ticket. Please try again.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                final ticketNo = formatTicketNumberFromTicket(ticket);
                await closeComposerSheetIfOpen(
                  _ComposeSupportResult.ticketCreated(ticketNo),
                );
              }

              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Blue header ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.mail_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email to Ticket',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send an email to create a ticket automatically',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: closeComposerSheetIfOpen,
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                    // ── Body ────────────────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom:
                              MediaQuery.of(sheetContext).viewInsets.bottom +
                                  20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // To: row with Copy Address + Open Email App
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  Text('To: ',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      )),
                                  Expanded(
                                    child: Text(
                                      _mailbox,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Copy Address button
                                  GestureDetector(
                                    onTap: () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: _mailbox));
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Email address copied'),
                                          backgroundColor: AppColors.success,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Text('Copy Address',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Open Email App (inline)
                                  GestureDetector(
                                    onTap: creatingTicket ? null : openEmailApp,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('Open Email App',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Subject
                            Text(
                              'SUBJECT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: subjectCtrl,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (allowDirectCreation) ...[
                              DropdownButtonFormField<String>(
                                initialValue: selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: categories
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setSheetState(() => selectedCategory = value);
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedPriority,
                                decoration: InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: _composePriorities
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setSheetState(() => selectedPriority = value);
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Message
                            Text(
                              'MESSAGE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: bodyCtrl,
                              maxLines: 6,
                              minLines: 4,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: allowDirectCreation
                                    ? 'Describe your issue. This text is used in email body and ticket description.'
                                    : 'Hi Support Team,\n\nI need help with:\n\n- Issue:\n...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tip: Attach screenshots/documents in your email. Your email will be converted into a ticket and visible in your Tickets list.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Bottom buttons: Copy Template + Send Email
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final content =
                                        'To: $_mailbox\nSubject: ${subjectCtrl.text.trim()}\n\n${bodyCtrl.text.trim()}';
                                    await Clipboard.setData(
                                        ClipboardData(text: content));
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Template copied to clipboard'),
                                        backgroundColor: AppColors.success,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    'Copy Template',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: creatingTicket
                                      ? null
                                      : allowDirectCreation
                                          ? createTicketNow
                                          : openEmailApp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: creatingTicket
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          allowDirectCreation
                                              ? 'Create Ticket'
                                              : 'Send Email',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              allowDirectCreation
                                  ? 'Create Ticket sends directly to backend, so it appears in Admin Support Tickets immediately.'
                                  : 'Send this email from your registered account. Admin must click Poll Inbox to convert it into a ticket.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      if (!mounted || composeResult == null) return;
      if (composeResult.emailOpened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email app opened for $_mailbox'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }
      final ticketNo = composeResult.ticketNo;
      if (ticketNo == null || ticketNo.isEmpty) return;
      setState(() {
        _lastActionMessage =
            'Ticket $ticketNo created. Admin can now see it in Support Tickets.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ticket $ticketNo created successfully and added to admin queue.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      subjectCtrl.dispose();
      bodyCtrl.dispose();
    }
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
          ? const Center(
              child: MeetTheMastersLoadingIndicator(
                label: 'Checking email service',
              ),
            )
          : RefreshIndicator(
              onRefresh: _canManageInbox ? _loadHealth : _bootstrap,
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
                          _canManageInbox
                              ? 'Service Health'
                              : 'Email-to-Ticket',
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
                          _canManageInbox
                              ? 'Manual Poll'
                              : 'Create Ticket by Email',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _canManageInbox
                              ? 'Trigger system email polling to convert incoming messages into tickets.'
                              : 'Send your issue from your email account to $_mailbox. Your ticket appears in Support Tickets after processing.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _canManageInbox
                              ? ElevatedButton(
                                  onPressed: _polling ? null : _triggerPoll,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
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
                                )
                              : ElevatedButton(
                                  onPressed: _composeSupportEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    'Compose Support Email',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                        if (!_canManageInbox) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Manual polling is managed by admin. You can always create tickets by email.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use your registered account email while sending to $_mailbox so backend can map it to your profile.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
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
