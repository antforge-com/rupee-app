import 'package:finadvise/app_theme.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:finadvise/services/services.dart';
import 'package:finadvise/shared/ticket_number_formatter.dart';
import 'package:flutter/material.dart';
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
    final bodyCtrl = TextEditingController();
    String selectedCategory = categories.first;
    String selectedPriority = 'MEDIUM';
    bool creatingTicket = false;
    bool composingSheetClosed = false;

    try {
      final composeResult = await showModalBottomSheet<_ComposeSupportResult>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
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
                    SnackBar(
                      content: Text(
                        'Unable to open email app right now. You can still create the ticket below.',
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

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Compose Support Email',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: closeComposerSheetIfOpen,
                          ),
                        ],
                      ),
                      Text(
                        'Support mailbox: $_mailbox',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: subjectCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (allowDirectCreation) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 6,
                        minLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Issue Details',
                          hintText:
                              'Describe your issue. This text is used in email body and ticket description.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: creatingTicket ? null : openEmailApp,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Open Email App',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (allowDirectCreation) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: creatingTicket ? null : createTicketNow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
                                    'Create Ticket Now',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        allowDirectCreation
                            ? 'Create Ticket Now sends directly to backend, so it appears in Admin Support Tickets immediately.'
                            : 'Send this email from your registered account. Admin must click Poll Inbox to convert it into a ticket.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        composingSheetClosed = true;
      });
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
