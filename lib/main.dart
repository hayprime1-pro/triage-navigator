import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'triage_engine.dart';
import 'storage.dart';

void main() => runApp(const TriageApp());

const _domains = [
  'Speech / Communication',
  'Mobility / Movement',
  'Functional / ADL',
  'Hearing',
  'Cognition',
];

const _riskFlags = [
  'Recent stroke',
  'Cardiac condition',
  'Hypertension',
  'Diabetes',
  'Recent surgery',
  'Severe pain',
  'Dizziness',
];

class TriageApp extends StatefulWidget {
  const TriageApp({super.key});

  @override
  State<TriageApp> createState() => _TriageAppState();
}

class _TriageAppState extends State<TriageApp> {
  ThemeMode _mode = ThemeMode.system;
  final _store = LocalStore();

  @override
  void initState() {
    super.initState();
    _store.loadTheme().then((v) {
      if (!mounted) return;
      setState(() {
        _mode = switch (v) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      });
    });
  }

  void _setMode(ThemeMode m) {
    setState(() => _mode = m);
    _store.saveTheme(switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B5BFD),
      brightness: Brightness.light,
    );
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8FA2FF),
      brightness: Brightness.dark,
    );
    ThemeData base(ColorScheme s) => ThemeData(
          colorScheme: s,
          useMaterial3: true,
          visualDensity: VisualDensity.standard,
          cardTheme: CardTheme(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: s.outlineVariant.withOpacity(0.7)),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 52),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(48, 48)),
            ),
          ),
        );

    return MaterialApp(
      title: 'BACR Triage',
      debugShowCheckedModeBanner: false,
      theme: base(light),
      darkTheme: base(dark),
      themeMode: _mode,
      home: AppShell(
        mode: _mode,
        onModeChanged: _setMode,
      ),
    );
  }
}

class HistoryEntry {
  HistoryEntry({required this.patient, required this.result});
  final String patient;
  final TriageResult result;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.mode, required this.onModeChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Draft form state (local only — no backend).
  final _nameCtrl = TextEditingController();
  final Set<String> _domainsSel = {};
  final Set<String> _risksSel = {};
  String? _redFlag; // 'Yes' | 'No'
  String? _formError;

  TriageResult? _lastResult;
  final List<HistoryEntry> _history = [];
  List<RoutingRule> _rules = defaultRules();
  final _store = LocalStore();

  @override
  void initState() {
    super.initState();
    _store.loadHistory().then((items) {
      if (!mounted || items.isEmpty) return;
      setState(() {
        _history.clear();
        _history.addAll(items.map((s) => HistoryEntry(
              patient: s.patient,
              result: resultFromJson(s.resultJson),
            )));
      });
    });
    _store.loadRules().then((r) {
      if (!mounted || r == null || r.isEmpty) return;
      setState(() => _rules = r);
    });
  }

  Future<void> _persistHistory() => _store.saveHistory(
        _history.map((e) => e.patient).toList(),
        _history.map((e) => e.result).toList(),
      );

  Future<void> _persistRules() => _store.saveRules(_rules);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  bool get _canCompute =>
      _redFlag != null && (_domainsSel.isNotEmpty || _risksSel.isNotEmpty);

  void _compute() {
    if (!_canCompute) {
      setState(() {
        if (_redFlag == null) {
          _formError = 'Please answer the Red flag question to continue.';
        } else {
          _formError = 'Select at least one domain or risk flag.';
        }
      });
      return;
    }
    setState(() {
      _formError = null;
      _lastResult = computeTriage(
        domainsCount: _domainsSel.length,
        riskScore: _risksSel.length,
        redFlagYes: _redFlag == 'Yes',
        rules: _rules,
      );
      _index = 1;
    });
  }

  void _clear() {
    setState(() {
      _nameCtrl.clear();
      _domainsSel.clear();
      _risksSel.clear();
      _redFlag = null;
      _formError = null;
    });
  }

  void _saveToHistory() {
    if (_lastResult == null) return;
    setState(() {
      _history.insert(
        0,
        HistoryEntry(patient: _nameCtrl.text.trim(), result: _lastResult!),
      );
      _index = 2;
    });
    _persistHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved to history (on this device).'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _go(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final pages = [
      _TriagePage(
        nameCtrl: _nameCtrl,
        domainsSel: _domainsSel,
        risksSel: _risksSel,
        redFlag: _redFlag,
        formError: _formError,
        canCompute: _canCompute,
        lastPreview: _livePreview(),
        onToggleDomain: (d) => setState(() {
          _domainsSel.contains(d)
              ? _domainsSel.remove(d)
              : _domainsSel.add(d);
          _formError = null;
        }),
        onToggleRisk: (r) => setState(() {
          _risksSel.contains(r) ? _risksSel.remove(r) : _risksSel.add(r);
          _formError = null;
        }),
        onRedFlag: (v) => setState(() {
          _redFlag = v;
          _formError = null;
        }),
        onCompute: _compute,
        onClear: _clear,
        onEditRules: () => _go(3),
      ),
      _ResultPage(
        result: _lastResult,
        patient: _nameCtrl.text,
        onNew: () => _go(0),
        onSave: _saveToHistory,
      ),
      _HistoryPage(
        history: _history,
        onOpen: (e) => setState(() {
          _lastResult = e.result;
          _nameCtrl.text = e.patient;
          _index = 1;
        }),
        onDelete: (i) {
          setState(() => _history.removeAt(i));
          _persistHistory();
        },
        onClearAll: () {
          setState(_history.clear);
          _persistHistory();
        },
        onNew: () => _go(0),
      ),
      _RulesPage(
        rules: _rules,
        onToggle: (i, v) {
          setState(() => _rules[i].enabled = v);
          _persistRules();
        },
        onEdit: (i, r) {
          setState(() => _rules[i] = r);
          _persistRules();
        },
        onReset: () {
          setState(() => _rules = defaultRules());
          _persistRules();
        },
      ),
      _SettingsPage(mode: widget.mode, onModeChanged: widget.onModeChanged),
    ];

    const dests = [
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Triage',
      ),
      NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: 'Result',
      ),
      NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'History',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Rules',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _ModeButton(
                  mode: widget.mode,
                  onModeChanged: widget.onModeChanged,
                ),
              ),
              destinations: dests
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _PageContainer(child: pages[_index]),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: _PageContainer(child: pages[_index])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: dests,
      ),
    );
  }

  TriageResult _livePreview() => computeTriage(
        domainsCount: _domainsSel.length,
        riskScore: _risksSel.length,
        redFlagYes: _redFlag == 'Yes',
        rules: _rules,
      );
}

class _PageContainer extends StatelessWidget {
  const _PageContainer({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            vertical: 16,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.onModeChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () =>
          onModeChanged(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}

// ---------------- Triage form page ----------------

class _TriagePage extends StatelessWidget {
  const _TriagePage({
    required this.nameCtrl,
    required this.domainsSel,
    required this.risksSel,
    required this.redFlag,
    required this.formError,
    required this.canCompute,
    required this.lastPreview,
    required this.onToggleDomain,
    required this.onToggleRisk,
    required this.onRedFlag,
    required this.onCompute,
    required this.onClear,
    required this.onEditRules,
  });

  final TextEditingController nameCtrl;
  final Set<String> domainsSel;
  final Set<String> risksSel;
  final String? redFlag;
  final String? formError;
  final bool canCompute;
  final TriageResult lastPreview;
  final ValueChanged<String> onToggleDomain;
  final ValueChanged<String> onToggleRisk;
  final ValueChanged<String?> onRedFlag;
  final VoidCallback onCompute;
  final VoidCallback onClear;
  final VoidCallback onEditRules;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 850;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Patient',
          subtitle: 'Optional — stored on this device only',
          icon: Icons.person_outline,
          child: TextField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Patient name or ID (optional)',
              hintText: 'e.g. Jane D. • BACR-001',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Functional Domains',
          subtitle: '${domainsSel.length} selected • 1 Simple • 2 Moderate • 3+ Complex',
          icon: Icons.grid_view_outlined,
          child: Semantics(
            label: 'Functional Domains',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final d in _domains)
                  FilterChip(
                    label: Text(d),
                    selected: domainsSel.contains(d),
                    showCheckmark: true,
                    tooltip: 'Toggle $d',
                    onSelected: (_) => onToggleDomain(d),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Risk Flags',
          subtitle: '${risksSel.length} selected • 0 Low • 1–2 Moderate • 3+ High',
          icon: Icons.flag_outlined,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final r in _riskFlags)
                FilterChip(
                  label: Text(r),
                  selected: risksSel.contains(r),
                  showCheckmark: true,
                  tooltip: 'Toggle $r',
                  onSelected: (_) => onToggleRisk(r),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Red Flag',
          subtitle: 'Red flag = immediate Refer Out',
          icon: Icons.emergency_outlined,
          child: Semantics(
            label: 'Red flag present?',
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: 'Yes', label: Text('Yes'), icon: Icon(Icons.warning_amber_outlined)),
                ButtonSegment(value: 'No', label: Text('No'), icon: Icon(Icons.check_circle_outline)),
              ],
              selected: redFlag == null ? const <String>{} : {redFlag!},
              showSelectedIcon: false,
              onSelectionChanged: (sel) =>
                  onRedFlag(sel.isEmpty ? null : sel.first),
            ),
          ),
        ),
        if (formError != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: s.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formError!,
                      style: TextStyle(color: s.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onCompute,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('Review & compute'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Clear'),
            ),
            TextButton.icon(
              onPressed: onEditRules,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Routing rules'),
            ),
          ],
        ),
        if (!canCompute)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Tip: answer Red flag and pick at least one domain or risk flag.',
              style: TextStyle(fontSize: 13),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroHeader(preview: lastPreview),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: form),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: _LivePreviewCard(result: lastPreview)),
            ],
          )
        else ...[
          form,
          const SizedBox(height: 14),
          _LivePreviewCard(result: lastPreview),
        ],
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.preview});
  final TriageResult preview;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [s.primary, s.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BACR Patient Triage',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: s.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fast, guided triage • ${preview.domainsCount} domains • ${preview.riskScore} risks',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: s.onPrimary.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.onPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.monitor_heart_outlined,
                  color: s.onPrimary, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({required this.result});
  final TriageResult result;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 4),
            const Text('Updates as you tap — no backend yet.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            _miniRow(context, 'Complexity', result.complexity,
                Icons.assessment_outlined),
            _miniRow(context, 'Risk', result.riskLevel,
                Icons.speed_outlined),
            _miniRow(context, 'Pathway', result.pathway,
                Icons.route_outlined),
            const SizedBox(height: 8),
            Text(result.nextStep,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _miniRow(BuildContext c, String k, String v, IconData i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(i, size: 18),
          const SizedBox(width: 8),
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------- Result page ----------------

class _ResultPage extends StatelessWidget {
  const _ResultPage({
    required this.result,
    required this.patient,
    required this.onNew,
    required this.onSave,
  });
  final TriageResult? result;
  final String patient;
  final VoidCallback onNew;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _EmptyState(
        icon: Icons.insights_outlined,
        title: 'No result yet',
        body: 'Complete a triage to see Complexity, Risk, Pathway and Next step here.',
        actionLabel: 'Start triage',
        onAction: onNew,
      );
    }
    final r = result!;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label:
              'Triage result. ${r.complexity} complexity. ${r.riskLevel} risk. ${r.pathway}. ${r.nextStep}',
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.trim().isEmpty
                        ? 'Triage result'
                        : 'Result • ${patient.trim()}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.domainsCount} domain(s) • ${r.riskScore} risk flag(s) • Red flag ${r.redFlagYes ? "Yes" : "No"}',
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      r.pathway,
                      key: ValueKey(r.pathway),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(r.nextStep),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final cols = wide ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                _metric(context, 'Complexity', r.complexity,
                    Icons.assessment_outlined),
                _metric(context, 'Risk Level', r.riskLevel,
                    Icons.speed_outlined),
                _metric(context, 'Pathway', r.pathway,
                    Icons.route_outlined),
                _metric(context, 'Next Step', r.nextStep,
                    Icons.arrow_forward_outlined),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save to history'),
            ),
            OutlinedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_outlined),
              label: const Text('New triage'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: r.summary(patient)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Summary copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy summary'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metric(BuildContext c, String title, String value, IconData icon) {
    final s = Theme.of(c).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: s.primary),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(c).textTheme.labelLarge),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

// ---------------- History ----------------

class _HistoryPage extends StatefulWidget {
  const _HistoryPage({
    required this.history,
    required this.onOpen,
    required this.onDelete,
    required this.onClearAll,
    required this.onNew,
  });
  final List<HistoryEntry> history;
  final ValueChanged<HistoryEntry> onOpen;
  final ValueChanged<int> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onNew;

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.history;
    if (history.isEmpty) {
      return _EmptyState(
        icon: Icons.history_outlined,
        title: 'No history yet',
        body: 'Saved triages stay on this device until the backend lands.',
        actionLabel: 'Start triage',
        onAction: widget.onNew,
      );
    }
    final q = _q.trim().toLowerCase();
    final matches = <int>[];
    for (var i = 0; i < history.length; i++) {
      final e = history[i];
      final hay =
          '${e.patient} ${e.result.pathway} ${e.result.complexity} ${e.result.riskLevel}'
              .toLowerCase();
      if (q.isEmpty || hay.contains(q)) matches.add(i);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${history.length} saved',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Copy history as JSON',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () async {
                final data = history
                    .map((e) => {
                          'patient': e.patient,
                          'result': resultToJson(e.result),
                        })
                    .toList();
                await Clipboard.setData(
                    ClipboardData(text: data.toString()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('History copied as JSON.')),
                  );
                }
              },
            ),
            TextButton.icon(
              onPressed: widget.onClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            labelText: 'Search history',
            hintText: 'Name, pathway, risk…',
            prefixIcon: Icon(Icons.search_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No matches. Try a different search.'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, k) {
              final i = matches[k];
              final e = history[i];
              final who = e.patient.trim().isEmpty
                  ? 'Unnamed patient'
                  : e.patient.trim();
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    child: Text('${i + 1}'),
                  ),
                  title: Text('$who • ${e.result.pathway}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${e.result.complexity} • ${e.result.riskLevel} risk • ${e.result.domainsCount}D/${e.result.riskScore}R'),
                  trailing: IconButton(
                    tooltip: 'Delete entry $who',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => widget.onDelete(i),
                  ),
                  onTap: () => widget.onOpen(e),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ---------------- Rules ----------------

class _RulesPage extends StatelessWidget {
  const _RulesPage({
    required this.rules,
    required this.onToggle,
    required this.onEdit,
    required this.onReset,
  });
  final List<RoutingRule> rules;
  final void Function(int, bool) onToggle;
  final void Function(int, RoutingRule) onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Local rules for now — Supabase sync comes with the backend. Edits apply instantly to scoring.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text('Routing rules (${rules.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rules.length,
          onReorder: (_, __) {},
          itemBuilder: (context, i) {
            final r = rules[i];
            return Card(
              key: ValueKey(r.id),
              child: SwitchListTile(
                value: r.enabled,
                onChanged: (v) => onToggle(i, v),
                title: Text('${i + 1}. ${r.title}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${r.condition}\n→ ${r.pathway}'),
                isThreeLine: true,
                secondary: IconButton(
                  tooltip: 'Edit ${r.title}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editDialog(context, r, (nr) =>
                      onEdit(i, nr)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _editDialog(
      BuildContext context, RoutingRule r, ValueChanged<RoutingRule> save) {
    final t = TextEditingController(text: r.title);
    final p = TextEditingController(text: r.pathway);
    final n = TextEditingController(text: r.nextStep);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${r.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: t,
                  decoration:
                      const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(
                  controller: p,
                  decoration:
                      const InputDecoration(labelText: 'Pathway')),
              const SizedBox(height: 8),
              TextField(
                  controller: n,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Next step')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final nr = r.copy()
                ..title = t.text.trim().isEmpty ? r.title : t.text.trim()
                ..pathway =
                    p.text.trim().isEmpty ? r.pathway : p.text.trim()
                ..nextStep =
                    n.text.trim().isEmpty ? r.nextStep : n.text.trim();
              save(nr);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ---------------- Settings ----------------

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.mode, required this.onModeChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Appearance',
          subtitle: 'Light, dark, or follow system',
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined)),
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Auto'),
                      icon: Icon(Icons.settings_suggest_outlined)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dark mode uses the same premium palette with proper contrast. Text scales with your system font size.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionCard(
          title: 'Accessibility',
          subtitle: 'Built in, not bolted on',
          icon: Icons.accessibility_new_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckRow('48px minimum tap targets on all buttons & chips'),
              _CheckRow('Screen-reader labels + live result announcements'),
              _CheckRow('Keyboard-focusable controls, visible focus order'),
              _CheckRow('No color-only meaning — icons + text on every state'),
              _CheckRow('Responsive to 320px phones up to desktop'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'About',
          subtitle: 'BACR Triage v1.0.0 • Flutter Web • backend not connected',
          icon: Icons.info_outline,
          child: Text(
            'Frontend-only build. History and rules live on-device until Supabase lands.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
