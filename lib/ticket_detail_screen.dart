// lib/features/admin/ticket_detail_screen.dart
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/auth_service.dart'; // AuthService import kiya senderId ke liye
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  final List<ConsultantModel> consultants;
  final String role; // ADMIN / CONSULTANT / USER

  const TicketDetailScreen({
    super.key,
    required this.ticket,
    required this.consultants,
    required this.role,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> with SingleTickerProviderStateMixin {
  final TicketService _ticketService = TicketService();
  final _replyCtrl = TextEditingController();
  late TabController _tabCtrl;

  Ticket? _ticket;
  List<TicketComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _isInternal = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _ticket = widget.ticket;
    _loadComments();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    // FIX 1: getComments ki jagah pura ticket fetch karke uske comments nikaal rahe hain
    final updatedTicket = await _ticketService.getTicketById(widget.ticket.id);
    if (mounted) {
      setState(() {
        _comments = updatedTicket?.comments ?? widget.ticket.comments;
        _loading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);

    // FIX 2: Sender ID nikaalna
    final userIdStr = await AuthService().getUserId();
    final senderId = int.tryParse(userIdStr ?? '0') ?? 0;

    // FIX 3: senderId pass kiya aur isInternal ki jagah isConsultantReply use kiya
    final comment = await _ticketService.addComment(
      widget.ticket.id, 
      msg, 
      senderId: senderId,
      isConsultantReply: _isInternal,
    );

    if (comment != null) {
      _replyCtrl.clear();
      setState(() => _comments.add(comment));
    }
    setState(() => _sending = false);
  }

  Future<void> _changeStatus(String status) async {
    await _ticketService.updateTicketStatus(widget.ticket.id, status);
    final updated = await _ticketService.getTicketById(widget.ticket.id);
    if (updated != null && mounted) setState(() => _ticket = updated);
  }

  Future<void> _assignToConsultant(int consultantId) async {
    await _ticketService.assignTicket(widget.ticket.id, consultantId);
    if (!mounted) return; 
    Navigator.pop(context);
    final updated = await _ticketService.getTicketById(widget.ticket.id);
    if (updated != null && mounted) setState(() => _ticket = updated);
  }

  void _showAssignSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Assign Ticket', style: AppTextStyles.h3),
          ),
          const Divider(),
          ...widget.consultants.map((c) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight.withOpacity(0.1), 
              child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
            ),
            title: Text(c.name, style: AppTextStyles.h4),
            subtitle: Text(c.designation ?? '', style: AppTextStyles.caption),
            trailing: _ticket?.consultantId == c.id
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : null,
            onTap: () => _assignToConsultant(c.id),
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showStatusSheet() {
    final statuses = ['OPEN', 'IN_PROGRESS', 'PENDING', 'RESOLVED', 'CLOSED', 'ESCALATED'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Change Status', style: AppTextStyles.h3),
          ),
          const Divider(),
          ...statuses.map((s) => ListTile(
            leading: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: getStatusColor(s), shape: BoxShape.circle),
            ),
            title: Text(s.replaceAll('_', ' '), style: AppTextStyles.h4),
            trailing: _ticket?.status == s ? const Icon(Icons.check, color: AppColors.success) : null,
            onTap: () { Navigator.pop(context); _changeStatus(s); },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket ?? widget.ticket;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #${ticket.id}', style: AppTextStyles.h4),
            StatusBadge(status: ticket.status), 
          ],
        ),
        actions: [
          if (widget.role == 'ADMIN') ...[
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _showAssignSheet,
              tooltip: 'Assign',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _showStatusSheet,
            tooltip: 'Change Status',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          tabs: const [
            Tab(text: 'Conversation'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Conversation Tab ──
          Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const EmptyState(icon: Icons.chat_bubble_outline, title: 'No messages yet')
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) => _CommentBubble(
                              comment: _comments[i],
                              isMe: _comments[i].authorRole == widget.role,
                            ),
                          ),
              ),
              _buildReplyBar(),
            ],
          ),

          // ── Details Tab ──
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailSection(
                  title: 'Ticket Info',
                  rows: [
                    _DetailRow('ID', '#${ticket.id}'),
                    // Title ki jagah ab category aati hai backend se
                    _DetailRow('Title/Category', ticket.category), 
                    _DetailRow('Status', ticket.status),
                    _DetailRow('Priority', ticket.priority),
                    
                    // FIX 4: Category ab non-nullable hai, toh null check ki zaroorat nahi hai
                    _DetailRow('Category', ticket.category),
                    
                    _DetailRow('Created', ticket.createdAt ?? '—'),
                    _DetailRow('Updated', ticket.updatedAt ?? '—'),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'People',
                  rows: [
                    if (ticket.userName != null) _DetailRow('Client', ticket.userName!),
                    if (ticket.consultantName != null) _DetailRow('Assigned To', ticket.consultantName!),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'SLA',
                  child: SlaStrip(ticket: ticket),
                ),
                if (ticket.description != null) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Description',
                    child: Text(ticket.description!, style: AppTextStyles.body),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          if (widget.role != 'USER')
            Row(
              children: [
                Switch(
                  value: _isInternal, 
                  onChanged: (v) => setState(() => _isInternal = v), 
                  activeThumbColor: AppColors.warning
                ),
                Text('Internal note', style: AppTextStyles.label.copyWith(color: _isInternal ? AppColors.warning : AppColors.textMuted)),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: _isInternal ? 'Internal note...' : 'Type a reply...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sending ? null : _sendReply,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isInternal ? AppColors.warning : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final TicketComment comment;
  final bool isMe;

  const _CommentBubble({required this.comment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight.withOpacity(0.1), 
              child: Text(
                (comment.authorName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: comment.isInternal
                    ? AppColors.gold.withOpacity(0.15) 
                    : isMe
                        ? AppColors.primaryLight
                        : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: comment.isInternal ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.isInternal)
                    const Text('🔒 Internal Note', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w700)),
                  if (!isMe && comment.authorName != null)
                    Text(comment.authorName!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isMe ? Colors.white70 : AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(comment.message, style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    comment.createdAt != null ? _formatTime(comment.createdAt!) : '',
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow>? rows;
  final Widget? child;

  const _DetailSection({required this.title, this.rows, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const Divider(height: 16),
          if (rows != null) ...rows!
          else if (child != null) child!,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.label)),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

// ─── MISSING WIDGETS ────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getStatusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: getStatusColor(status),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class SlaStrip extends StatelessWidget {
  final Ticket ticket;

  const SlaStrip({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    // Basic fallback SLA display
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('Service Level Agreement', style: AppTextStyles.label),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Active',
            style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}