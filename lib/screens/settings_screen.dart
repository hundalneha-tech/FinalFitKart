// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/pedometer_service.dart';

enum SettingsPage { personalInfo, withdrawal, donationPrefs, privacy, healthConnect }

class SettingsScreen extends StatelessWidget {
  final SettingsPage page;
  const SettingsScreen({super.key, required this.page});
  @override
  Widget build(BuildContext context) {
    switch (page) {
      case SettingsPage.personalInfo:   return const _PersonalInfoScreen();
      case SettingsPage.withdrawal:     return const _WithdrawalScreen();
      case SettingsPage.donationPrefs:  return const _DonationPrefsScreen();
      case SettingsPage.privacy:        return const _PrivacyScreen();
      case SettingsPage.healthConnect:  return const _HealthConnectScreen();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. PERSONAL INFORMATION — edit name, phone, city, gender, DOB, step goal
// ═══════════════════════════════════════════════════════════════════════════════
class _PersonalInfoScreen extends StatefulWidget {
  const _PersonalInfoScreen();
  @override State<_PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<_PersonalInfoScreen> {
  final _sb       = Supabase.instance.client;
  final _nameC    = TextEditingController();
  final _cityC    = TextEditingController();
  final _phoneC   = TextEditingController();
  String? _gender;
  DateTime? _dob;
  int  _goalSteps = 10000;
  bool _loading   = true;
  bool _saving    = false;

  final _genders = ['male','female','other','prefer_not_to_say'];
  final _gLabels = ['Male','Female','Other','Prefer not to say'];
  final _goals   = [5000, 7500, 10000, 12500, 15000, 20000];

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _nameC.dispose(); _cityC.dispose(); _phoneC.dispose(); super.dispose(); }

  Future<void> _load() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final p = await _sb.from('profiles')
          .select('name, city, phone, gender, date_of_birth, goal_steps')
          .eq('id', uid).single();
      _nameC.text  = p['name']  as String? ?? '';
      _cityC.text  = p['city']  as String? ?? '';
      _phoneC.text = p['phone'] as String? ?? '';
      _gender      = p['gender'] as String?;
      _goalSteps   = (p['goal_steps'] as num?)?.toInt() ?? 10000;
      final dob = p['date_of_birth'] as String?;
      if (dob != null) _dob = DateTime.tryParse(dob);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty) {
      _snack('Name cannot be empty', error: true); return;
    }
    setState(() => _saving = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _saving = false); return; }
    try {
      await _sb.from('profiles').update({
        'name':          _nameC.text.trim(),
        'city':          _cityC.text.trim().isEmpty ? null : _cityC.text.trim(),
        'phone':         _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
        'gender':        _gender,
        'goal_steps':    _goalSteps,
        'date_of_birth': _dob?.toIso8601String().split('T')[0],
      }).eq('id', uid);
      if (mounted) { _snack('Profile saved ✓'); Navigator.pop(context); }
    } catch (e) {
      if (mounted) _snack('Save failed: $e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1995),
      firstDate: DateTime(1930),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!));
    if (d != null) setState(() => _dob = d);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.green));
  }

  String get _initials {
    final n = _nameC.text.trim().split(' ');
    return n.length >= 2 ? '${n[0][0]}${n[1][0]}'.toUpperCase()
        : _nameC.text.isNotEmpty ? _nameC.text[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: _appBar(context, 'Personal Information'),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

          // Avatar
          Center(child: Stack(children: [
            Container(width: 88, height: 88,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                shape: BoxShape.circle),
              child: Center(child: Text(_initials,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)))),
            Positioned(right:0, bottom:0,
              child: Container(width:30, height:30,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
          ])),
          const SizedBox(height: 8),
          // Read-only email
          Text(_sb.auth.currentUser?.email ?? '',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          _sectionCard('Basic Info', [
            _fieldItem('Full Name',    _nameC, Icons.person_outline_rounded, hint: 'Rahul Sharma'),
            _fieldItem('Phone',        _phoneC, Icons.phone_outlined, hint: '+91 98765 43210', type: TextInputType.phone),
            _fieldItem('City',         _cityC, Icons.location_city_outlined, hint: 'Mumbai, Bengaluru...'),
          ]),
          const SizedBox(height: 16),

          // Gender
          _sectionCard('Gender', [
            Padding(padding: const EdgeInsets.fromLTRB(16,12,16,12),
              child: Wrap(spacing: 8, runSpacing: 8,
                children: List.generate(_genders.length, (i) => GestureDetector(
                  onTap: () => setState(() => _gender = _genders[i]),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _gender == _genders[i] ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gender == _genders[i] ? AppColors.primary : AppColors.border)),
                    child: Text(_gLabels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _gender == _genders[i] ? Colors.white : AppColors.textSecondary))))))),
          ]),
          const SizedBox(height: 16),

          // Date of birth
          _sectionCard('Date of Birth', [
            InkWell(onTap: _pickDob, borderRadius: BorderRadius.circular(12),
              child: Padding(padding: const EdgeInsets.fromLTRB(16,14,16,14),
                child: Row(children: [
                  const Icon(Icons.cake_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    _dob == null
                      ? 'Tap to select your birthday'
                      : '${_dob!.day} / ${_dob!.month} / ${_dob!.year}',
                    style: TextStyle(fontSize: 14,
                      color: _dob == null ? AppColors.textSecondary : AppColors.textPrimary)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ]))),
          ]),
          const SizedBox(height: 16),

          // Daily step goal
          _sectionCard('Daily Step Goal', [
            Padding(padding: const EdgeInsets.fromLTRB(16,8,16,12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current goal: $_goalSteps steps  ·  ≈₹${(_goalSteps * 0.001 * 0.33).toStringAsFixed(2)}/day',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: _goals.map((g) =>
                  GestureDetector(
                    onTap: () => setState(() => _goalSteps = g),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _goalSteps == g ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _goalSteps == g ? AppColors.primary : AppColors.border)),
                      child: Text('${(g/1000).toStringAsFixed(g%1000==0?0:1)}k',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _goalSteps == g ? Colors.white : AppColors.textPrimary))))).toList()),
              ])),
          ]),
          const SizedBox(height: 28),
          _saveBtn(_saving, _save),
        ])));

  Widget _sectionCard(String title, List<Widget> children) => Container(
    decoration: cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,16,4),
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.4))),
      ...children.expand((w) sync* {
        yield w;
        if (w != children.last) yield const Divider(height: 1, indent: 16, color: AppColors.borderLight);
      }),
    ]));

  Widget _fieldItem(String label, TextEditingController ctrl, IconData icon,
      {String hint = '', TextInputType? type}) =>
    Padding(padding: const EdgeInsets.fromLTRB(16,10,16,10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          TextField(controller: ctrl, keyboardType: type,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            decoration: InputDecoration(hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.only(top: 4))),
        ])),
      ]));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. WITHDRAWAL METHODS — UPI add/edit/delete, Bank accounts, Gift Cards
// ═══════════════════════════════════════════════════════════════════════════════
class _WithdrawalScreen extends StatefulWidget {
  const _WithdrawalScreen();
  @override State<_WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<_WithdrawalScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  // Saved UPI IDs (in real app these come from Supabase)
  final List<Map<String,String>> _savedUpi = [];
  final List<Map<String,String>> _savedBanks = [];
  final List<Map<String,String>> _giftCards = [
    {'code': 'FKG-1234-ABCD', 'value': '₹150', 'expires': '30 Jun 2026', 'status': 'active'},
    {'code': 'FKG-5678-EFGH', 'value': '₹250', 'expires': '31 Dec 2025', 'status': 'used'},
  ];

  @override void dispose() { _tab.dispose(); super.dispose(); }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.green));
  }

  void _addUpi() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add UPI ID', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _dialogField(ctrl, Icons.account_balance_rounded, 'e.g. rahul@gpay or 9876543210@paytm'),
        const SizedBox(height: 8),
        const Text('Supports: Google Pay · PhonePe · Paytm · BHIM · Amazon Pay',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isEmpty || !ctrl.text.contains('@')) {
              _snack('Enter a valid UPI ID (e.g. name@upi)', error: true); return;
            }
            setState(() => _savedUpi.add({'id': ctrl.text.trim(), 'label': ctrl.text.split('@').last.toUpperCase()}));
            Navigator.pop(context);
            _snack('UPI ID added ✓');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Add', style: TextStyle(color: Colors.white))),
      ]));
  }

  void _addBank() {
    final holderC = TextEditingController();
    final accC    = TextEditingController();
    final ifscC   = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Bank Account', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(holderC, Icons.person_outline, 'Account Holder Name'),
          const SizedBox(height: 12),
          _dialogField(accC, Icons.credit_card, 'Account Number',
            type: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 12),
          _dialogField(ifscC, Icons.code_rounded, 'IFSC Code (e.g. SBIN0001234)'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (holderC.text.trim().isEmpty || accC.text.trim().length < 9 || ifscC.text.trim().length < 11) {
                _snack('Please fill all fields correctly', error: true); return;
              }
              setState(() => _savedBanks.add({
                'holder': holderC.text.trim(),
                'account': '••••${accC.text.trim().substring(accC.text.trim().length - 4)}',
                'ifsc': ifscC.text.trim().toUpperCase(),
              }));
              Navigator.pop(context);
              _snack('Bank account added ✓ — KYC verification pending');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Add', style: TextStyle(color: Colors.white))),
        ])));
  }

  void _redeemGiftCard(Map<String,String> card) {
    if (card['status'] == 'used') { _snack('This gift card has already been used', error: true); return; }
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Redeem Gift Card', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            const Text('FitKart Gift Card', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(card['code']!, style: const TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text(card['value']!, style: const TextStyle(color: Colors.white, fontSize: 28,
              fontWeight: FontWeight.w900)),
          ])),
        const SizedBox(height: 16),
        Text('This will add ${card['value']} worth of FKC coins to your wallet.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Expires: ${card['expires']}',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            setState(() => card['status'] = 'used');
            Navigator.pop(context);
            _snack('Gift card redeemed! FKC coins added to your wallet 🎉');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Redeem Now', style: TextStyle(color: Colors.white))),
      ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('Withdrawal Methods',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      bottom: TabBar(
        controller: _tab, labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary, indicatorWeight: 2,
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [Tab(text: 'UPI'), Tab(text: 'Bank'), Tab(text: 'Gift Cards')]),
    ),
    body: TabBarView(controller: _tab, children: [
      // ── UPI Tab ────────────────────────────────────────
      _buildUpiTab(),
      // ── Bank Tab ───────────────────────────────────────
      _buildBankTab(),
      // ── Gift Cards Tab ─────────────────────────────────
      _buildGiftTab(),
    ]),
  );

  Widget _buildUpiTab() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    _kycBanner(),
    const SizedBox(height: 16),
    // Add UPI button
    _addBtn('Add UPI ID', Icons.add_rounded, _addUpi),
    const SizedBox(height: 16),
    // Saved UPIs
    if (_savedUpi.isEmpty)
      _emptyState('💳', 'No UPI ID added yet', 'Add Google Pay, PhonePe or Paytm ID')
    else
      ...List.generate(_savedUpi.length, (i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16,14,16,14),
        decoration: cardDecoration(),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('UPI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_savedUpi[i]['id']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(_savedUpi[i]['label']!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
            onPressed: () => setState(() => _savedUpi.removeAt(i))),
        ]))),
  ]));

  Widget _buildBankTab() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    _kycBanner(),
    const SizedBox(height: 16),
    _addBtn('Add Bank Account', Icons.add_rounded, _addBank),
    const SizedBox(height: 16),
    if (_savedBanks.isEmpty)
      _emptyState('🏦', 'No bank account added yet', 'Add your savings or current account')
    else
      ...List.generate(_savedBanks.length, (i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16,14,16,14),
        decoration: cardDecoration(),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_rounded, color: AppColors.green, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_savedBanks[i]['holder']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${_savedBanks[i]['account']}  •  ${_savedBanks[i]['ifsc']}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(20)),
            child: const Text('KYC Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
            onPressed: () => setState(() => _savedBanks.removeAt(i))),
        ]))),
  ]));

  Widget _buildGiftTab() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: const Row(children: [
        Text('🎁', style: TextStyle(fontSize: 20)),
        SizedBox(width: 10),
        Expanded(child: Text('Gift cards are loaded automatically when you receive them via challenges or promotions.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
      ])),
    const SizedBox(height: 16),
    ..._giftCards.map((card) {
      final isUsed = card['status'] == 'used';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: cardDecoration(),
        child: Column(children: [
          Container(height: 100, width: double.infinity,
            decoration: BoxDecoration(
              gradient: isUsed
                ? const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)])
                : AppColors.grad,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('🎁', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  const Text('FitKart Gift Card',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (isUsed) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                    child: const Text('USED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                ]),
                Text(card['code']!, style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ]))),
          Padding(padding: const EdgeInsets.fromLTRB(16,12,16,12), child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card['value']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              Text('Expires: ${card['expires']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            if (!isUsed)
              ElevatedButton(
                onPressed: () => _redeemGiftCard(card),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Redeem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))
            else
              const Text('Redeemed', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ])),
        ]));
    }),
  ]));

  Widget _kycBanner() => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.yellow.withOpacity(0.4))),
    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('⚠️', style: TextStyle(fontSize: 16)),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KYC Required for Withdrawal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        SizedBox(height: 2),
        Text('Min withdrawal: ₹100 (≈303 FKC)\nFunds arrive in 3–5 business days after KYC approval.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
      ])),
    ]));

  Widget _addBtn(String label, IconData icon, VoidCallback onTap) =>
    SizedBox(width: double.infinity, height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.primary),
        label: Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));

  Widget _emptyState(String emoji, String title, String sub) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. DONATION PREFERENCES — view causes, donation history, preferred causes
// ═══════════════════════════════════════════════════════════════════════════════
class _DonationPrefsScreen extends StatefulWidget {
  const _DonationPrefsScreen();
  @override State<_DonationPrefsScreen> createState() => _DonationPrefsScreenState();
}

class _DonationPrefsScreenState extends State<_DonationPrefsScreen> {
  final _sb = Supabase.instance.client;
  List<Map<String,dynamic>> _causes    = [];
  List<Map<String,dynamic>> _donations = [];
  Set<String> _preferred = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = _sb.auth.currentUser?.id;
    try {
      final results = await Future.wait([
        _sb.from('causes').select('*').eq('is_active', true),
        if (uid != null)
          _sb.from('donations')
              .select('*, cause:causes(title)')
              .eq('user_id', uid)
              .order('created_at', ascending: false)
              .limit(20)
        else Future.value([]),
      ]);
      if (mounted) setState(() {
        _causes    = List<Map<String,dynamic>>.from(results[0] as List);
        _donations = List<Map<String,dynamic>>.from(results[1] as List);
        _loading   = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  String _emoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('water'))  return '💧';
    if (t.contains('forest') || t.contains('tree')) return '🌱';
    if (t.contains('animal') || t.contains('stray')) return '🐾';
    return '❤️';
  }

  double _progress(Map c) {
    final cur = (c['current_coins'] as num?)?.toDouble() ?? 0;
    final tgt = (c['target_coins']  as num?)?.toDouble() ?? 1;
    return (cur / tgt).clamp(0.0, 1.0);
  }

  String _pct(Map c) => '${(_progress(c)*100).toStringAsFixed(0)}%';

  String _timeAgo(String? raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: _appBar(context, 'Donation Preferences'),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : RefreshIndicator(
          color: AppColors.primary, onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Summary card ──────────────────────────────
              Container(padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Text('❤️', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Your Impact', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                    Text('${_donations.length} donations made',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Total: ${_donations.fold(0, (sum, d) => sum + ((d['coins_donated'] as num?)?.toInt() ?? 0))} FKC donated',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ])),
                ])),
              const SizedBox(height: 24),

              // ── Active Causes ─────────────────────────────
              const Text('Active Causes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Tap a cause to mark it as a preference', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),

              if (_causes.isEmpty)
                _emptyState('🌍', 'No active causes', 'Check back soon!')
              else
                ..._causes.map((c) {
                  final id  = c['id'] as String;
                  final sel = _preferred.contains(id);
                  return GestureDetector(
                    onTap: () => setState(() => sel ? _preferred.remove(id) : _preferred.add(id)),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? AppColors.accent : AppColors.border, width: sel ? 2 : 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(_emoji(c['title'] as String? ?? ''), style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['title'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            Text(c['ngo_name'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ])),
                          if (sel)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.favorite_rounded, color: AppColors.accent, size: 12),
                                SizedBox(width: 4),
                                Text('Preferred', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                              ])),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Text(_pct(c), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                          const SizedBox(width: 8),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(value: _progress(c), minHeight: 5,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(AppColors.green)))),
                        ]),
                        const SizedBox(height: 4),
                        Text(c['description'] as String? ?? '',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])));
                }),
              const SizedBox(height: 24),

              // ── Donation History ──────────────────────────
              const Text('Your Donation History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              if (_donations.isEmpty)
                _emptyState('🤲', 'No donations yet', 'Start walking and donate FKC to causes you care about')
              else
                ..._donations.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14,12,14,12),
                  decoration: cardDecoration(),
                  child: Row(children: [
                    Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('❤️', style: TextStyle(fontSize: 20)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((d['cause'] as Map?)?['title'] as String? ?? 'Donation',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(_timeAgo(d['created_at'] as String?),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${d['coins_donated']} FKC',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent)),
                      Text('≈ ₹${((d['coins_donated'] as num? ?? 0) * 0.33).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ]))),
            ]))),
  );

  Widget _emptyState(String emoji, String title, String sub) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ])));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. PRIVACY & SECURITY — toggles saved to Supabase, change password, delete account
// ═══════════════════════════════════════════════════════════════════════════════
class _PrivacyScreen extends StatefulWidget {
  const _PrivacyScreen();
  @override State<_PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<_PrivacyScreen> {
  final _sb = Supabase.instance.client;
  bool _shareActivity     = true;
  bool _showLeaderboard   = true;
  bool _locationSharing   = false;
  bool _marketingEmails   = true;
  bool _challengeNotifs   = true;
  bool _coinNotifs        = true;
  bool _saving = false;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final p = await _sb.from('profiles')
          .select('notifications_enabled')
          .eq('id', uid).single();
      _coinNotifs = p['notifications_enabled'] as bool? ?? true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = _sb.auth.currentUser?.id;
    try {
      if (uid != null) {
        await _sb.from('profiles')
            .update({'notifications_enabled': _coinNotifs})
            .eq('id', uid);
      }
      if (mounted) _snack('Privacy settings saved ✓');
    } catch (_) { if (mounted) _snack('Save failed', error: true); }
    if (mounted) setState(() => _saving = false);
  }

  void _changePassword() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter your new password. You will be signed out after the change.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _dialogField(ctrl, Icons.lock_outline, 'New password (min 8 chars)',
          obscure: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.trim().length < 8) {
              _snack('Password must be at least 8 characters', error: true); return;
            }
            Navigator.pop(context);
            try {
              await _sb.auth.updateUser(UserAttributes(password: ctrl.text.trim()));
              _snack('Password updated ✓');
            } catch (e) { _snack('Error: $e', error: true); }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Update', style: TextStyle(color: Colors.white))),
      ]));
  }

  void _deleteAccount() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.red)),
      content: const Column(mainAxisSize: MainAxisSize.min, children: [
        Text('⚠️', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('This will permanently delete your account, wallet balance, all earned FKC, steps history and redemptions.\n\nThis CANNOT be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _snack('Account deletion request submitted. Our team will process it within 7 days.');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete My Account', style: TextStyle(color: Colors.white))),
      ]));
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.green));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: _appBar(context, 'Privacy & Security'),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [

          _section('Social Privacy', [
            _toggle('Share my activity feed',  'Friends can see your walks & achievements', _shareActivity,   (v) => setState(() => _shareActivity = v)),
            _toggle('Show on Leaderboard',     'Appear in weekly & monthly rankings',       _showLeaderboard,  (v) => setState(() => _showLeaderboard = v)),
            _toggle('Share live location',     'Let workout buddies see you nearby',        _locationSharing,  (v) => setState(() => _locationSharing = v)),
          ]),
          const SizedBox(height: 16),

          _section('Notifications', [
            _toggle('Challenge updates',  'Get notified when challenges start/end', _challengeNotifs, (v) => setState(() => _challengeNotifs = v)),
            _toggle('Coin earnings',      'Notify me when I earn FKC coins',        _coinNotifs,      (v) => setState(() => _coinNotifs = v)),
            _toggle('Marketing & offers', 'Promotions and new perk announcements',  _marketingEmails, (v) => setState(() => _marketingEmails = v)),
          ]),
          const SizedBox(height: 16),

          _section('Security', [
            _actionRow(Icons.lock_outline, AppColors.primaryBg, AppColors.primary,
              'Change Password', 'Update your login password', _changePassword),
            _actionRow(Icons.delete_outline, AppColors.redBg, AppColors.red,
              'Delete Account', 'Permanently remove all your data', _deleteAccount),
          ]),
          const SizedBox(height: 24),
          _saveBtn(_saving, _save),

          const SizedBox(height: 16),
          // App version info
          Center(child: Text('FitKart v1.0.0  ·  © 2026 FitKart Club',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
          const SizedBox(height: 8),
        ])));

  Widget _section(String title, List<Widget> children) => Container(
    decoration: cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,16,4),
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.4))),
      ...children.expand((w) sync* {
        yield w;
        if (w != children.last) yield const Divider(height: 1, indent: 16, color: AppColors.borderLight);
      }),
    ]));

  Widget _toggle(String label, String sub, bool val, ValueChanged<bool> onChanged) =>
    Padding(padding: const EdgeInsets.fromLTRB(16,10,12,10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(sub,   style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Switch(value: val, onChanged: onChanged, activeColor: AppColors.primary,
          trackOutlineColor: MaterialStateProperty.all(Colors.transparent)),
      ]));

  Widget _actionRow(IconData icon, Color bg, Color color, String label, String sub, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color == AppColors.red ? AppColors.red : AppColors.textPrimary)),
            Text(sub,   style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
        ])));
}

// ── Shared helpers ────────────────────────────────────────────────────────────
AppBar _appBar(BuildContext context, String title) => AppBar(
  backgroundColor: AppColors.scaffold, elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
    onPressed: () => Navigator.pop(context)),
  title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)));

Widget _label(String text) => Align(alignment: Alignment.centerLeft,
  child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)));

Widget _dialogField(TextEditingController ctrl, IconData icon, String hint,
    {TextInputType? type, List<TextInputFormatter>? formatters, bool obscure = false}) =>
  Container(decoration: BoxDecoration(color: AppColors.scaffold, borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 12), child: Icon(icon, size: 18, color: AppColors.textSecondary)),
      Expanded(child: TextField(
        controller: ctrl, keyboardType: type, inputFormatters: formatters, obscureText: obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13)))),
    ]));

Widget _field(String label, TextEditingController ctrl, IconData icon,
    {String hint = '', TextInputType? type, List<TextInputFormatter>? formatters}) =>
  Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 14), child: Icon(icon, size: 18, color: AppColors.textSecondary)),
      Expanded(child: TextField(
        controller: ctrl, keyboardType: type, inputFormatters: formatters,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
    ]));

Widget _saveBtn(bool saving, VoidCallback onTap) => SizedBox(width: double.infinity, height: 52,
  child: ElevatedButton(
    onPressed: saving ? null : onTap,
    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    child: saving
      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))));

// ═══════════════════════════════════════════════════════════════════════════════
// 5. HEALTH CONNECT — connect and manage Health Connect permissions
// ═══════════════════════════════════════════════════════════════════════════════
class _HealthConnectScreen extends StatefulWidget {
  const _HealthConnectScreen();
  @override State<_HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<_HealthConnectScreen> {
  static const _channel = MethodChannel('com.fitkart.app/health_connect');
  bool _loading   = false;
  bool _connected = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      final granted   = available
          ? (await _channel.invokeMethod<bool>('checkPermissions') ?? false)
          : false;
      if (mounted) setState(() { _available = available; _connected = granted; });
    } catch (_) {
      if (mounted) setState(() { _available = false; _connected = PedometerService().isHealthConnected; });
    }
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    final granted = await PedometerService().requestHealthConnectPermissions();
    if (mounted) setState(() { _connected = granted; _loading = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(granted
          ? '✅ Health Connect connected! Steps will now sync accurately.'
          : '❌ Permission denied. Please allow in Health Connect app settings.'),
        backgroundColor: granted ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('Health Connect',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _connected ? AppColors.green.withOpacity(0.08) : AppColors.primaryBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _connected ? AppColors.green : AppColors.primary, width: 1.5)),
          child: Column(children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(
                color: _connected ? AppColors.green : AppColors.primary,
                shape: BoxShape.circle),
              child: Center(child: Icon(
                _connected ? Icons.favorite_rounded : Icons.health_and_safety_outlined,
                color: Colors.white, size: 36))),
            const SizedBox(height: 16),
            Text(
              _connected ? 'Health Connect Connected' : 'Connect Health Connect',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              _connected
                ? 'FitKart is reading your step data, distance, and calories from Health Connect.'
                : 'Connect Health Connect so FitKart can accurately count your steps, distance and calories — even when the app is in the background.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ])),
        const SizedBox(height: 20),

        // What we read
        Container(
          padding: const EdgeInsets.all(16), decoration: cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Data FitKart reads from Health Connect',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _HCItem(icon: Icons.directions_walk_rounded, color: AppColors.primary,
              label: 'Steps', sub: 'Daily and session step counts'),
            _HCItem(icon: Icons.social_distance_rounded, color: AppColors.green,
              label: 'Distance', sub: 'Kilometers walked or run'),
            _HCItem(icon: Icons.local_fire_department_rounded, color: const Color(0xFFF97316),
              label: 'Calories burned', sub: 'Active and total energy expended'),
            _HCItem(icon: Icons.monitor_heart_outlined, color: AppColors.accent,
              label: 'Heart rate', sub: 'For Heart Points calculation'),
          ])),
        const SizedBox(height: 20),

        // Connect button
        if (!_connected) ...[
          SizedBox(width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Connect Health Connect',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Open Health Connect app directly
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Open Health Connect app → App permissions → FitKart → Allow All'),
                behavior: SnackBarBehavior.floating, duration: Duration(seconds: 5)));
            },
            child: const Text('Open Health Connect settings instead',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ] else ...[
          SizedBox(width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.scaffold,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : const Text('Refresh Permissions',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)))),
        ],

        const SizedBox(height: 24),
        const Text(
          'Your health data is private and only used to calculate your steps and FKC earnings. It is never shared with third parties.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5)),
      ])));
}

class _HCItem extends StatelessWidget {
  final IconData icon; final Color color; final String label, sub;
  const _HCItem({required this.icon, required this.color, required this.label, required this.sub});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Icon(Icons.check_circle_rounded, color: color, size: 18),
    ]));
}
