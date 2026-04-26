part of '../../main.dart';

/// Reporting module for admins.
///
/// Provides:
/// - room utilization (minutes scheduled / assumed weekly capacity)
/// - teacher load (sum of subject units)
extension ReportsModule on _DashboardScreenState {
  Widget buildReportsModule() {
    final scheduledRoomNames =
        _visibleSchedule.map((sc) => sc.room.name).toSet().toList();
    final scheduledTeacherNames =
        _visibleSchedule.map((sc) => sc.teacher.name).toSet().toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Room Utilization'),
            Tab(text: 'Teacher Load'),
          ],
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduledRoomNames.length,
              itemBuilder: (context, i) {
                final report = _schedulerService
                    .getRoomUtilizationReport(scheduledRoomNames[i]);
                return Card(
                  child: ListTile(
                    title: Text(report['roomName']),
                    subtitle:
                        LinearProgressIndicator(value: report['utility'] / 100),
                    trailing:
                        Text('${report['utility'].toStringAsFixed(1)}% Usage'),
                  ),
                );
              },
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduledTeacherNames.length,
              itemBuilder: (context, i) {
                final report = _schedulerService
                    .getTeacherLoadReport(scheduledTeacherNames[i]);
                return Card(
                  child: ListTile(
                    title: Text(report['teacher']),
                    subtitle:
                        Text('Total Assigned: ${report['totalUnits']} Units'),
                    trailing: const Icon(Icons.person),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
