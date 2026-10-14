import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/repositories/app_api_client.dart';
import '../../core/ui/components/kpb_toast.dart';

/// Alumni self-application form (Phase 3).
///
/// A student who was admitted uploads proof (admission letter / diploma
/// scan URL — we don't re-host it; they paste a link to Drive / Dropbox /
/// their KPB storage bucket) and submits for admin review. Once approved,
/// they show up in the public alumni directory with a verified badge.
class AlumniApplyScreen extends StatefulWidget {
  const AlumniApplyScreen({super.key});

  @override
  State<AlumniApplyScreen> createState() => _AlumniApplyScreenState();
}

class _AlumniApplyScreenState extends State<AlumniApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = AppApiClient();

  final _universityCtrl = TextEditingController();
  final _programmeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _proofUrlCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingStatus = true;
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _universityCtrl.dispose();
    _programmeCtrl.dispose();
    _yearCtrl.dispose();
    _countryCtrl.dispose();
    _proofUrlCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final me = await _api.getMyAlumniStatus();
      if (!mounted) return;
      setState(() {
        _currentStatus = me['alumniStatus'] as String?;
        _universityCtrl.text = (me['alumniUniversity'] as String?) ?? '';
        _programmeCtrl.text = (me['alumniProgramme'] as String?) ?? '';
        _yearCtrl.text = (me['alumniGraduationYear']?.toString()) ?? '';
        _countryCtrl.text = (me['alumniCountryCode'] as String?) ?? '';
        _bioCtrl.text = (me['alumniBioFr'] as String?) ?? '';
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStatus = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.applyAsAlumni(
        university: _universityCtrl.text.trim(),
        programme: _programmeCtrl.text.trim(),
        graduationYear: int.parse(_yearCtrl.text.trim()),
        proofUrl: _proofUrlCtrl.text.trim(),
        countryCode: _countryCtrl.text.trim().isEmpty
            ? null
            : _countryCtrl.text.trim().toUpperCase(),
        bioFr: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      KpbToast.success('application_sent_admin'.tr, context: context);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      KpbToast.error('alumni_apply_submit_failed'.tr, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('alumni_apply_title'.tr)),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStatus != null && _currentStatus != 'none')
                      _StatusBanner(status: _currentStatus!),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _universityCtrl,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_university'.tr,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'form_required'.tr
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _programmeCtrl,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_programme'.tr,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'form_required'.tr
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_year'.tr,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final y = int.tryParse((v ?? '').trim());
                        if (y == null) return 'alumni_apply_year_invalid'.tr;
                        if (y < 1980 || y > DateTime.now().year + 10) {
                          return 'alumni_apply_year_out_of_range'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countryCtrl,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_country'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proofUrlCtrl,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_proof_url'.tr,
                        helperText: 'alumni_apply_proof_helper'.tr,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'alumni_apply_proof_required'.tr
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: 'alumni_apply_bio'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('alumni_apply_submit'.tr),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final String msg;
    late final Color color;
    switch (status) {
      case 'pending':
        msg = 'alumni_status_pending'.tr;
        color = Colors.orange.shade100;
        break;
      case 'approved':
        msg = 'alumni_status_approved'.tr;
        color = Colors.green.shade100;
        break;
      case 'rejected':
        msg = 'alumni_status_rejected'.tr;
        color = Colors.red.shade100;
        break;
      default:
        msg = '';
        color = Colors.transparent;
    }
    if (msg.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg),
    );
  }
}
