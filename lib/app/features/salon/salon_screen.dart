import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/external_link.dart';

/// Salon KPB Virtuel — annual 2-day in-app event (Phase 3).
///
/// Universities from Canada / France / Morocco answer questions live. This
/// screen lists upcoming editions, their sessions, and lets a student RSVP
/// so we can push reminder notifications 24h and 1h before the session.
///
/// Video is hosted externally (Jitsi / Meet / Zoom) — the "Rejoindre" button
/// just opens `joinUrl` in the browser. We don't bake a WebRTC stack into
/// the app; universities keep their own recording and platform of choice.
class SalonScreen extends StatefulWidget {
  /// Optional [apiClient] for tests; production uses [AppApiClient] when null.
  const SalonScreen({super.key, this.apiClient});

  final AppApiClient? apiClient;

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  late final AppApiClient _api = widget.apiClient ?? AppApiClient();
  bool _loading = true;
  String? _error;
  List<dynamic> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listSalonEvents();
      if (!mounted) return;
      setState(() {
        _events = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'salon_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _openEvent(Map<String, dynamic> event) async {
    final slug = event['slug'] as String?;
    if (slug == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SalonEventScreen(slug: slug, apiClient: _api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('salon_title'.tr)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  static const _scrollPhysics =
      AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: _scrollPhysics,
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 160),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: _scrollPhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: KpbErrorState(
              title: 'salon_unavailable_title'.tr,
              subtitle: _error!,
              onRetry: _load,
            ),
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      return ListView(
        physics: _scrollPhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: KpbEmptyState(
              icon: Icons.event_available_outlined,
              title: 'salon_no_edition_title'.tr,
              subtitle: 'salon_no_edition_subtitle'.tr,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: _scrollPhysics,
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = _events[i] as Map<String, dynamic>;
        return _EventCard(event: e, onTap: () => _openEvent(e));
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final Map<String, dynamic> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final isEn = ctrl.localeCode == 'en';
    final name = ((isEn ? event['nameEn'] : event['nameFr']) as String?) ??
        (event['nameFr'] as String?) ??
        '';
    final year = event['year']?.toString() ?? '';
    final start = event['startAt'] as String?;
    final end = event['endAt'] as String?;
    final desc =
        ((isEn ? event['descriptionEn'] : event['descriptionFr']) as String?) ??
            (event['descriptionFr'] as String?) ??
            '';
    final status = (event['status'] as String?) ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$name $year',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (status == 'live')
                    Chip(
                      label: Text('salon_live_now'.tr),
                      backgroundColor: KpbColors.error,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatRange(start, end),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right),
                  label: Text('salon_view_sessions'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatRange(String? startIso, String? endIso) {
    if (startIso == null) return '';
    final start = DateTime.tryParse(startIso)?.toLocal();
    final end = endIso != null ? DateTime.tryParse(endIso)?.toLocal() : null;
    if (start == null) return '';
    if (end == null) return _fmt(start);
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return sameDay
        ? '${_fmt(start)} — ${_fmtTime(end)}'
        : '${_fmt(start)} → ${_fmt(end)}';
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${_fmtTime(d)}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
}

/// Detail view — lists sessions for the selected event and lets the student
/// register / unregister.
class _SalonEventScreen extends StatefulWidget {
  const _SalonEventScreen({required this.slug, this.apiClient});

  final String slug;
  final AppApiClient? apiClient;

  @override
  State<_SalonEventScreen> createState() => _SalonEventScreenState();
}

class _SalonEventScreenState extends State<_SalonEventScreen> {
  late final AppApiClient _api = widget.apiClient ?? AppApiClient();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _event = const {};
  Set<String> _registeredSessionIds = <String>{};

  static const _scrollPhysics =
      AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getSalonEvent(widget.slug),
        _api.listMySalonRegistrations(),
      ]);
      if (!mounted) return;
      final regs = results[1] as List<dynamic>;
      setState(() {
        _event = results[0] as Map<String, dynamic>;
        _registeredSessionIds = regs
            .map((r) =>
                ((r as Map<String, dynamic>)['sessionId'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'salon_program_load_error'.tr;
        _loading = false;
      });
    }
  }

  /// Sessions dont l'inscription/annulation est en cours : un double tap
  /// envoyait deux requêtes contradictoires.
  final Set<String> _togglingSessionIds = <String>{};

  Future<void> _toggleRegister(Map<String, dynamic> session) async {
    final id = session['id'] as String?;
    if (id == null || !_togglingSessionIds.add(id)) return;
    final isRegistered = _registeredSessionIds.contains(id);
    try {
      if (isRegistered) {
        await _api.cancelSalonRegistration(id);
        if (!mounted) return;
        setState(() => _registeredSessionIds.remove(id));
      } else {
        await _api.registerForSalonSession(id);
        if (!mounted) return;
        setState(() => _registeredSessionIds.add(id));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('salon_rsvp_error'.tr)),
      );
    } finally {
      _togglingSessionIds.remove(id);
    }
  }

  // Lien venu du serveur : ouvert par le helper qui valide le schéma et
  // n'échoue pas en exception si l'URL est mal formée.
  Future<void> _join(String? joinUrl) async {
    await kpbOpenExternalUrlString(joinUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final localizedName = (ctrl.localeCode == 'en'
        ? _event['nameEn']
        : _event['nameFr']) as String?;
    final name = localizedName ??
        (_event['nameFr'] as String?) ??
        'salon_fallback_title'.tr;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: _scrollPhysics,
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 160),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: _scrollPhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: KpbErrorState(
              title: 'salon_program_unavailable_title'.tr,
              subtitle: _error!,
              onRetry: _load,
            ),
          ),
        ],
      );
    }
    final sessions = (_event['sessions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (sessions.isEmpty) {
      return ListView(
        physics: _scrollPhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: KpbEmptyState(
              icon: Icons.schedule_outlined,
              title: 'salon_program_upcoming_title'.tr,
              subtitle: 'salon_program_upcoming_subtitle'.tr,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: _scrollPhysics,
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = sessions[i];
        final id = s['id'] as String? ?? '';
        final isRegistered = _registeredSessionIds.contains(id);
        return _SessionCard(
          session: s,
          isRegistered: isRegistered,
          onToggleRegister: () => _toggleRegister(s),
          onJoin: () => _join(s['joinUrl'] as String?),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isRegistered,
    required this.onToggleRegister,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool isRegistered;
  final VoidCallback onToggleRegister;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final isEn = ctrl.localeCode == 'en';
    final title =
        ((isEn ? session['titleEn'] : session['titleFr']) as String?) ??
            (session['titleFr'] as String?) ??
            '';
    final host = (session['hostName'] as String?) ?? '';
    final desc = ((isEn ? session['descriptionEn'] : session['descriptionFr'])
            as String?) ??
        (session['descriptionFr'] as String?) ??
        '';
    final startIso = session['startAt'] as String?;
    final duration = session['durationMinutes'] as int? ?? 45;
    final status = (session['status'] as String?) ?? 'scheduled';
    final joinUrl = (session['joinUrl'] as String?) ?? '';

    final start =
        startIso != null ? DateTime.tryParse(startIso)?.toLocal() : null;
    final isLive = status == 'live';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (isLive)
                  Chip(
                    label: Text('salon_session_live'.tr),
                    backgroundColor: KpbColors.error,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            if (host.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('salon_session_host'.trParams({'host': host}),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (start != null) ...[
              const SizedBox(height: 4),
              Text(
                '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} '
                '${start.hour.toString().padLeft(2, '0')}h${start.minute.toString().padLeft(2, '0')} · $duration min',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (isLive && joinUrl.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.video_call),
                      label: Text('salon_join'.tr),
                      onPressed: onJoin,
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(isRegistered
                          ? Icons.check_circle
                          : Icons.event_available),
                      label: Text(isRegistered
                          ? 'salon_registration_confirmed'.tr
                          : 'salon_register'.tr),
                      onPressed: onToggleRegister,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
