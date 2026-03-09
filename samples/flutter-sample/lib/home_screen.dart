import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deeplink_sdk/deeplink_sdk.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_LogEntry> _log = [_LogEntry('SDK configured. Ready to test.')];
  String _createdLinkUrl = '';
  bool _isFetching = false;
  bool _isCreating = false;

  void _append(String message) {
    setState(() => _log.add(_LogEntry(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deeplink SDK Sample'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [

                // ── Deferred Deep Link ──────────────────────────────────────
                _Section(
                  title: 'Deferred Deep Link',
                  children: [
                    _ActionTile(
                      icon: Icons.wifi_tethering,
                      label: _isFetching ? 'Fetching…' : 'Get Init Data (force)',
                      enabled: !_isFetching,
                      onTap: () async {
                        _append('Fetching init data…');
                        setState(() => _isFetching = true);
                        final data = await Deeplink.getInitData(force: true);
                        setState(() => _isFetching = false);
                        if (data != null) {
                          _append('✅ Matched!');
                          _append('   dest: ${data.destinationUrl ?? "—"}');
                          _append('   androidUrl: ${data.androidUrl ?? "—"}');
                          _append('   metadata: ${data.metadata}');
                        } else {
                          _append('⚠️  No match (no click fingerprint found)');
                        }
                      },
                    ),
                    _ActionTile(
                      icon: Icons.refresh,
                      label: 'Reset Init State',
                      onTap: () async {
                        await Deeplink.resetInitState();
                        _append('🔄 Init state reset — next getInitData() will re-fetch');
                      },
                    ),
                  ],
                ),

                // ── Create Link ─────────────────────────────────────────────
                _Section(
                  title: 'Create Link',
                  children: [
                    _ActionTile(
                      icon: Icons.add_link,
                      label: _isCreating ? 'Creating…' : 'Create Deep Link',
                      enabled: !_isCreating,
                      onTap: () async {
                        _append('Creating link…');
                        setState(() => _isCreating = true);
                        final link = await Deeplink.createLink(
                          destinationUrl: 'https://yourapp.com/product/123',
                          iosUrl: 'myapp://product/123',
                          androidUrl: 'myapp://product/123',
                          params: {'product_id': '123', 'source': 'flutter-sample'},
                          title: 'Sample Product',
                          utmSource: 'sample',
                          utmMedium: 'flutter',
                          utmCampaign: 'sdk-test',
                        );
                        setState(() => _isCreating = false);
                        if (link != null) {
                          setState(() => _createdLinkUrl = link.url);
                          _append('✅ Link created: ${link.url}');
                          _append('   alias: ${link.alias}');
                        } else {
                          _append('❌ Error creating link');
                          _append('   (Is the backend running and API key correct?)');
                        }
                      },
                    ),
                    if (_createdLinkUrl.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.copy, size: 18),
                        title: Text(
                          _createdLinkUrl,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _createdLinkUrl));
                          _append('📋 Copied to clipboard');
                        },
                      ),
                  ],
                ),

                // ── Event Tracking ──────────────────────────────────────────
                _Section(
                  title: 'Event Tracking',
                  children: [
                    _ActionTile(
                      icon: Icons.touch_app,
                      label: 'Track: button_tapped',
                      onTap: () async {
                        await Deeplink.track('button_tapped', {'screen': 'home', 'button': 'cta'});
                        _append('📊 Tracked: button_tapped {screen: home, button: cta}');
                      },
                    ),
                    _ActionTile(
                      icon: Icons.shopping_cart,
                      label: 'Track: purchase',
                      onTap: () async {
                        await Deeplink.track('purchase', {'amount': 49.99, 'currency': 'USD'});
                        _append('📊 Tracked: purchase {amount: 49.99, currency: USD}');
                      },
                    ),
                    _ActionTile(
                      icon: Icons.person_add,
                      label: 'Track: signup',
                      onTap: () async {
                        await Deeplink.track('signup', {'method': 'email'});
                        _append('📊 Tracked: signup {method: email}');
                      },
                    ),
                  ],
                ),

              ],
            ),
          ),

          // ── Log ────────────────────────────────────────────────────────────
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF1E1E1E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        const Text(
                          'Log',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _log.clear()),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _log.length,
                      itemBuilder: (_, i) {
                        final entry = _log[_log.length - 1 - i];
                        return Text(
                          entry.text,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: entry.text.startsWith('❌')
                                ? Colors.redAccent
                                : entry.text.startsWith('✅')
                                    ? Colors.greenAccent
                                    : entry.text.startsWith('📊')
                                        ? Colors.lightBlueAccent
                                        : Colors.white70,
                          ),
                        );
                      },
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

// ── Helpers ────────────────────────────────────────────────────────────────────

class _LogEntry {
  final String text;
  _LogEntry(this.text);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
      title: Text(label, style: TextStyle(color: enabled ? null : Colors.grey)),
      onTap: enabled ? onTap : null,
      dense: true,
    );
  }
}
