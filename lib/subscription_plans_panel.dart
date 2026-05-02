// lib/subscription_plans_panel.dart
// ════════════════════════════════════════════════════════════════════════════
// Subscription Plans Panel - Matches SubscriptionPlansPanel.tsx exactly
// Features:
//   - Display subscription plans in responsive grid
//   - Add/Edit plan modal
//   - Feature list display
//   - Original & discounted pricing
//   - Plan tags (PREMIUM, POPULAR, etc.)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'services/comprehensive_api_service.dart';

class SubscriptionPlansPanel extends StatefulWidget {
  const SubscriptionPlansPanel({super.key});

  @override
  State<SubscriptionPlansPanel> createState() =>
      _SubscriptionPlansPanelState();
}

class _SubscriptionPlansPanelState extends State<SubscriptionPlansPanel> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String _error = '';

  Map<String, dynamic>? _editingPlan;
  bool _showModal = false;

  final _nameCtrl = TextEditingController();
  final _origPriceCtrl = TextEditingController();
  final _discPriceCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _featuresCtrl = TextEditingController();

  String _formError = '';
  bool _formSubmitting = false;
  
  late ComprehensiveApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ComprehensiveApiService();
    _loadPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _origPriceCtrl.dispose();
    _discPriceCtrl.dispose();
    _tagCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final plansData = await _apiService.getAllSubscriptionPlans();
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(
            plansData.map((p) {
              if (p is Map<String, dynamic>) {
                return p;
              }
              return {};
            }),
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load plans: $e';
          _loading = false;
        });
      }
    }
  }

  void _openModal({Map<String, dynamic>? plan}) {
    if (plan != null) {
      _editingPlan = plan;
      _nameCtrl.text = plan['name'] ?? '';
      _origPriceCtrl.text = '${plan['originalPrice'] ?? 0}';
      _discPriceCtrl.text = '${plan['discountPrice'] ?? 0}';
      _tagCtrl.text = plan['tag'] ?? '';
      _featuresCtrl.text = plan['features'] ?? '';
    } else {
      _editingPlan = null;
      _nameCtrl.clear();
      _origPriceCtrl.clear();
      _discPriceCtrl.clear();
      _tagCtrl.clear();
      _featuresCtrl.clear();
    }
    _formError = '';
    setState(() => _showModal = true);
  }

  void _closeModal() {
    setState(() => _showModal = false);
  }

  Future<void> _handleSubmit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Plan name is required');
      return;
    }
    if (name[0].contains(RegExp(r'[0-9]'))) {
      setState(() => _formError = 'Plan name cannot start with a number');
      return;
    }

    setState(() {
      _formSubmitting = true;
      _formError = '';
    });

    try {
      final planData = {
        'name': name,
        'originalPrice': int.tryParse(_origPriceCtrl.text) ?? 0,
        'discountPrice': int.tryParse(_discPriceCtrl.text) ?? 0,
        'tag': _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        'features': _featuresCtrl.text.trim(),
      };

      bool success;
      if (_editingPlan != null) {
        success = await _apiService.updateSubscriptionPlan(
          _editingPlan!['id'] as int,
          planData,
        );
      } else {
        final result = await _apiService.createSubscriptionPlan(planData);
        success = result != null;
      }

      if (success && mounted) {
        _closeModal();
        _loadPlans();
      } else if (mounted) {
        setState(() => _formError = 'Failed to save plan. Please try again.');
      }
    } catch (e) {
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _formSubmitting = false);
      }
    }
  }

  String _formatIndianCurrency(int amount) {
    if (amount == 0) return 'Free';
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+(?!\d))'),
      (match) => '${match.group(1)},',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription Plans',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage subscription plans available to users.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openModal(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add New Plan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Content
                if (_loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading plans...',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_error.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  )
                else if (_plans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No subscription plans found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "Add New Plan" to create one.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _plans.length,
                    itemBuilder: (_, idx) =>
                        _buildPlanCard(_plans[idx]),
                  ),
              ],
            ),
          ),

          // Modal
          if (_showModal)
            _buildModal(),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      plan['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (plan['tag'] != null && plan['tag'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          plan['tag'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _openModal(plan: plan);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(plan);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pricing
          Row(
            children: [
              Text(
                _formatIndianCurrency(plan['discountPrice'] ?? 0),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              if ((plan['originalPrice'] ?? 0) > (plan['discountPrice'] ?? 0))
                Text(
                  _formatIndianCurrency(plan['originalPrice'] ?? 0),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Features
          if (plan['features'] != null && plan['features'].toString().isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FEATURES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: (plan['features'] as String)
                          .split('+')
                          .map((f) => f.trim())
                          .where((f) => f.isNotEmpty)
                          .map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color:
                                            AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Plan'),
          content: Text(
            'Are you sure you want to delete "${plan['name']}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await _apiService.deleteSubscriptionPlan(
                  plan['id'] as int,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Plan "${plan['name']}" deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadPlans();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete plan'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModal() {
    return GestureDetector(
      onTap: _closeModal,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 20, 12, 0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _editingPlan != null
                              ? 'Edit Plan'
                              : 'Add New Plan',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _closeModal,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (_formError.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(
                                bottom: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formError,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      const Color(0xFFB91C1C),
                                ),
                              ),
                            ),

                          // Name
                          _buildFormField(
                            label: 'Plan Name *',
                            controller: _nameCtrl,
                            hint: 'e.g. Elite',
                          ),
                          const SizedBox(height: 16),

                          // Prices
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Original Price (₹) *',
                                  controller:
                                      _origPriceCtrl,
                                  keyboardType:
                                      TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Discount Price (₹) *',
                                  controller:
                                      _discPriceCtrl,
                                  keyboardType:
                                      TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Tag
                          _buildFormField(
                            label: 'Tag (Optional)',
                            controller: _tagCtrl,
                            hint: 'e.g. PREMIUM',
                          ),
                          const SizedBox(height: 16),

                          // Features
                          _buildFormField(
                            label: 'Features',
                            controller: _featuresCtrl,
                            hint:
                                'Separate features with a plus sign (+)',
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _closeModal,
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _formSubmitting
                              ? null
                              : _handleSubmit,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.primary,
                            foregroundColor:
                                Colors.white,
                          ),
                          child: _formSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                          Colors.white,
                                        ),
                                  ),
                                )
                              : Text(
                                  _editingPlan !=
                                          null
                                      ? 'Save Changes'
                                      : 'Create Plan',
                                  style: GoogleFonts
                                      .inter(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType =
        TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

