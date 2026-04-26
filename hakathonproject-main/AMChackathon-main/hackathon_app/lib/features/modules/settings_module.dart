part of '../../main.dart';

/// Settings module.
///
/// Provides a small set of toggles and actions:
/// - theme mode switch (delegated to the app shell)
/// - notification toggle (UI-only in this prototype)
/// - admin utilities (clear schedule data, export CSV)
extension SettingsModule on _DashboardScreenState {
  Widget buildSettingsModule() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('System Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Institution Name'),
                subtitle: Text(_institutionName),
                trailing: const Icon(Icons.edit),
                onTap: () => _showEditSettingDialog(
                    'Institution Name',
                    _institutionName,
                    (v) => setState(() => _institutionName = v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('Conflict Notifications'),
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
            ],
          ),
        ),
        if (!_isTeacher) ...[
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Schedule Data',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                setState(() => _schedulerService.clearSchedule(
                      courseId: widget.currentUser.courseId,
                      userName: widget.currentUser.name,
                      userId: widget.currentUser.id,
                    ));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data cleared.')));
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Export CSV Backup'),
              onTap: () {
                final csv = _schedulerService.generateCsvExport();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('CSV Export Ready'),
                    content: SingleChildScrollView(child: Text(csv)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'))
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
