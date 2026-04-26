part of '../../main.dart';

/// History logs module (admin).
///
/// Streams recent audit logs from Firestore via `HistoryService.getLogs()` and
/// renders them as a list.
extension HistoryLogsModule on _DashboardScreenState {
  Widget buildHistoryLogsModule() {
    return StreamBuilder<List<HistoryLog>>(
      stream: HistoryService.getLogs(courseId: widget.currentUser.courseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No activity logs found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final log = snapshot.data![index];
            IconData icon;
            Color color;
            switch (log.action) {
              case ActionType.add:
                icon = Icons.add_circle_outline;
                color = Colors.green;
                break;
              case ActionType.update:
                icon = Icons.edit_outlined;
                color = Colors.orange;
                break;
              case ActionType.delete:
                icon = Icons.delete_outline;
                color = Colors.red;
                break;
            }

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              title: Text(log.details,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(
                  'By ${log.userName} • ${_formatDateTime(log.timestamp)}',
                  style: const TextStyle(fontSize: 12)),
            );
          },
        );
      },
    );
  }
}
