import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Note: Adjust the import paths according to your actual project structure
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/auth_service.dart';
import 'package:finadvise/services/onboarding_service.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM USER PROFILE SCREEN
// Features: Dynamic Income/Expense lists, Real-time edits, 
//           Fixed Type Errors, MNC-grade Design.
// ════════════════════════════════════════════════════════════════════════════

class UserProfileScreen extends StatefulWidget {
  final int? userId; // <-- FIXED: Added nullable userId to fix "named parameter" & "int?" errors

  const UserProfileScreen({
    super.key,
    this.userId, // <-- FIXED: Accepting userId here
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isSaving = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  // Dynamic Lists for Finances
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with your actual service call
      // Example: final profile = await OnboardingService().getProfile();
      
      // Mock Data for demonstration
      await Future.delayed(const Duration(milliseconds: 800));
      _nameCtrl.text = "Rahul Sharma";
      _phoneCtrl.text = "9876543210";
      _locationCtrl.text = "Mumbai, India";
      
      setState(() {
        _incomes = [
          {"label": "Salary", "amount": 85000},
        ];
        _expenses = [
          {"label": "Rent", "amount": 25000},
        ];
      });
    } catch (e) {
      _showSnackBar("Failed to load profile", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfileData() async {
    setState(() => _isSaving = true);
    try {
      // ════════════════════════════════════════════════════════════════════════
      // ERROR FIX: Use Map<String, dynamic> instead of Map<String, String>.
      // Nested arrays (List<Map>) cannot be assigned directly to String fields.
      // ════════════════════════════════════════════════════════════════════════
      final Map<String, dynamic> payload = {
        "name": _nameCtrl.text,
        "phoneNumber": _phoneCtrl.text,
        "location": _locationCtrl.text,
        "dob": _dobCtrl.text.isNotEmpty ? _dobCtrl.text : null,
        "incomeItems": _incomes,
        "expenseItems": _expenses,
      };

      // Convert the payload to a JSON string for the multipart request
      final String jsonStringData = jsonEncode(payload);

      // Example of actual Multipart Request implementation matching OpenAPI spec
      /*
      if (widget.userId != null) {
        var request = http.MultipartRequest('PUT', Uri.parse('http://52.55.178.31:8081/api/onboarding/${widget.userId}'));
        request.fields['data'] = jsonStringData; // This securely maps the nested JSON!
        var response = await request.send();
      }
      */

      // Simulating API call
      await Future.delayed(const Duration(seconds: 1));
      
      _showSnackBar("Profile updated successfully!");
    } catch (e) {
      _showSnackBar("Error saving profile", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── ADD INCOME/EXPENSE DIALOG ──────────────────────────────────────────────
  void _showAddFinanceDialog(bool isIncome) {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isIncome ? "Add Income" : "Add Expense",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: "Label (e.g. Salary, Rent)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount",
                prefixText: "₹ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                setState(() {
                  final newItem = {
                    "label": labelCtrl.text,
                    "amount": double.tryParse(amountCtrl.text) ?? 0.0
                  };
                  if (isIncome) {
                    _incomes.add(newItem);
                  } else {
                    _expenses.add(newItem);
                  }
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("Add", style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          "My Profile",
          style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1D4ED8),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: const Color(0xFF1D4ED8),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Personal"),
            Tab(text: "Finances"),
            Tab(text: "Plan"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalTab(),
          _buildFinancesTab(),
          _buildSubscriptionTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfileData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    "Save Changes",
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── TAB 1: PERSONAL DETAILS ────────────────────────────────────────────────
  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.person, size: 50, color: Colors.blue.shade200),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField("Full Name", Icons.person_outline, _nameCtrl),
          const SizedBox(height: 16),
          _buildTextField("Phone Number", Icons.phone_outlined, _phoneCtrl, isNumber: true),
          const SizedBox(height: 16),
          _buildTextField("Location", Icons.location_on_outlined, _locationCtrl),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
        ),
      ),
    );
  }

  // ─── TAB 2: FINANCES ────────────────────────────────────────────────────────
  Widget _buildFinancesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinanceSection("Income Sources", _incomes, true),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildFinanceSection("Monthly Expenses", _expenses, false),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(String title, List<Map<String, dynamic>> items, bool isIncome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1D4ED8)),
              onPressed: () => _showAddFinanceDialog(isIncome),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Center(child: Text("No items added yet", style: GoogleFonts.inter(color: Colors.grey.shade500))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green.shade600 : Colors.red.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(item['label'], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("₹ ${item['amount']}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            isIncome ? _incomes.removeAt(index) : _expenses.removeAt(index);
                          });
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          )
      ],
    );
  }

  // ─── TAB 3: SUBSCRIPTION ────────────────────────────────────────────────────
  Widget _buildSubscriptionTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Current Plan", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text("ELITE", style: GoogleFonts.inter(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                  ],
                ),
                const SizedBox(height: 24),
                Text("Active Subscription", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text("Renews on Dec 31, 2026", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _showSnackBar("Upgrade plans coming soon!");
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Change Plan", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8), fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}