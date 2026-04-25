import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicContactScreen extends StatefulWidget {
  const PublicContactScreen({super.key});

  @override
  State<PublicContactScreen> createState() => _PublicContactScreenState();
}

class _PublicContactScreenState extends State<PublicContactScreen> {
  final StaticContentService _staticService = StaticContentService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool _startsWithLetter(String value) {
    return RegExp(r'^[A-Za-z]').hasMatch(value.trim());
  }

  bool _startsWithCapital(String value) {
    return RegExp(r'^[A-Z]').hasMatch(value.trim());
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final ok = await _staticService.submitContactMessage(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _sending = false;
      _sent = ok;
      _error = ok ? null : 'Message could not be sent. Please try again.';
    });

    if (ok) {
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _messageCtrl.clear();
    }
  }

  Future<void> _launchExternal(String raw) async {
    final uri = Uri.parse(raw);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 940;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Contact Us',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactHero(
                    onBackHome: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 28),
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(flex: 4, child: _ContactInfoPanel()),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: _ContactFormCard(
                                formKey: _formKey,
                                nameCtrl: _nameCtrl,
                                phoneCtrl: _phoneCtrl,
                                emailCtrl: _emailCtrl,
                                messageCtrl: _messageCtrl,
                                sending: _sending,
                                sent: _sent,
                                error: _error,
                                onSubmit: _submit,
                                onSendAnother: () {
                                  setState(() {
                                    _sent = false;
                                    _error = null;
                                  });
                                },
                                startsWithLetter: _startsWithLetter,
                                startsWithCapital: _startsWithCapital,
                                isValidEmail: _isValidEmail,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const _ContactInfoPanel(),
                            const SizedBox(height: 24),
                            _ContactFormCard(
                              formKey: _formKey,
                              nameCtrl: _nameCtrl,
                              phoneCtrl: _phoneCtrl,
                              emailCtrl: _emailCtrl,
                              messageCtrl: _messageCtrl,
                              sending: _sending,
                              sent: _sent,
                              error: _error,
                              onSubmit: _submit,
                              onSendAnother: () {
                                setState(() {
                                  _sent = false;
                                  _error = null;
                                });
                              },
                              startsWithLetter: _startsWithLetter,
                              startsWithCapital: _startsWithCapital,
                              isValidEmail: _isValidEmail,
                            ),
                          ],
                        ),
                  const SizedBox(height: 24),
                  _QuickActionBar(
                    onEmail: () => _launchExternal('mailto:support@meetthemasters.in'),
                    onCall: () => _launchExternal('tel:+919999999999'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactHero extends StatelessWidget {
  final VoidCallback onBackHome;

  const _ContactHero({required this.onBackHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4C81), Color(0xFF0F766E), Color(0xFF38BDF8)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: onBackHome,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.35)),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Contact Us',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Talk to the team behind the platform.',
            style: GoogleFonts.inter(
              fontSize: 34,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Questions about advisory sessions, plans, bookings, or support tickets can start here.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoPanel extends StatelessWidget {
  const _ContactInfoPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _InfoCard(
          icon: Icons.email_outlined,
          title: 'Email Us',
          value: 'support@meetthemasters.in',
          subtitle: 'We reply within 24 hours',
        ),
        SizedBox(height: 16),
        _InfoCard(
          icon: Icons.call_outlined,
          title: 'Call Us',
          value: '+91 99999 99999',
          subtitle: 'Mon - Sat, 9 AM - 6 PM IST',
        ),
        SizedBox(height: 16),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: 'Office',
          value: 'Hyderabad, Telangana',
          subtitle: 'India - 500081',
        ),
        SizedBox(height: 16),
        _OfficeHoursCard(),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEAF7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFECF8FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeHoursCard extends StatelessWidget {
  const _OfficeHoursCard();

  @override
  Widget build(BuildContext context) {
    final hours = const [
      ('Monday - Friday', '9:00 AM - 6:00 PM'),
      ('Saturday', '10:00 AM - 2:00 PM'),
      ('Sunday', 'Closed'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4C81), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Office Hours',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          ...hours.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                  ),
                  Text(
                    item.$2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController messageCtrl;
  final bool sending;
  final bool sent;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onSendAnother;
  final bool Function(String value) startsWithLetter;
  final bool Function(String value) startsWithCapital;
  final bool Function(String value) isValidEmail;

  const _ContactFormCard({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.messageCtrl,
    required this.sending,
    required this.sent,
    required this.error,
    required this.onSubmit,
    required this.onSendAnother,
    required this.startsWithLetter,
    required this.startsWithCapital,
    required this.isValidEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCEAF7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4D78).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: sent
          ? _SuccessState(onSendAnother: onSendAnother)
          : Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Us a Message',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Fill in the form below and the team will get back to you shortly.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        error!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 640;
                      final nameField = Expanded(
                        child: _ContactField(
                          controller: nameCtrl,
                          label: 'Full Name',
                          hint: 'Your full name',
                          icon: Icons.person_outline_rounded,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Full name is required.';
                            if (!startsWithLetter(text)) {
                              return 'Name must start with a letter.';
                            }
                            if (!startsWithCapital(text)) {
                              return 'Name must start with a capital letter.';
                            }
                            return null;
                          },
                        ),
                      );
                      final phoneField = Expanded(
                        child: _ContactField(
                          controller: phoneCtrl,
                          label: 'Phone',
                          hint: '+91 XXXXX XXXXX',
                          icon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Phone number is required.';
                            return null;
                          },
                        ),
                      );
                      return stacked
                          ? Column(
                              children: [
                                Row(children: [nameField]),
                                const SizedBox(height: 16),
                                Row(children: [phoneField]),
                              ],
                            )
                          : Row(
                              children: [
                                nameField,
                                const SizedBox(width: 16),
                                phoneField,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),
                  _ContactField(
                    controller: emailCtrl,
                    label: 'Email Address',
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Email address is required.';
                      if (!isValidEmail(text)) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _ContactField(
                    controller: messageCtrl,
                    label: 'Message',
                    hint: 'How can we help you?',
                    icon: Icons.message_outlined,
                    maxLines: 6,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Message is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sending ? null : onSubmit,
                      icon: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: Text(sending ? 'Sending...' : 'Send Message'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ContactField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String? value)? validator;

  const _ContactField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: maxLines == 1 ? Icon(icon) : null,
            alignLabelWithHint: true,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FBFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCEAF7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCEAF7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.6),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines == 1 ? 16 : 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  final VoidCallback onSendAnother;

  const _SuccessState({required this.onSendAnother});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 42,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Message Sent!',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thank you for reaching out. The team will get back to you within 24 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onSendAnother,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFFA8D5F0)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: const Text('Send Another'),
        ),
      ],
    );
  }
}

class _QuickActionBar extends StatelessWidget {
  final VoidCallback onEmail;
  final VoidCallback onCall;

  const _QuickActionBar({
    required this.onEmail,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEAF7)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prefer direct contact? Use email or call during office hours.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onEmail,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email'),
              ),
              FilledButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                label: const Text('Call'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
