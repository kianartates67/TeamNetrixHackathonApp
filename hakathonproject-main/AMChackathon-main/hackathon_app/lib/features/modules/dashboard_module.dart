part of '../../main.dart';

/// Dashboard module: summary stats + live room status.
///
/// Uses `_visibleSchedule` which is either:
/// - the full schedule (admin), or
/// - filtered schedule for the current teacher (teacher role)
extension DashboardModule on _DashboardScreenState {
  Widget buildDashboardModule() {
    final source = _visibleSchedule;
    final scheduledRooms = source.map((sc) => sc.room.name).toSet().toList();
    final scheduledSections =
        source.map((sc) => sc.section.name).toSet().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard(
                  'Subjects',
                  source.map((sc) => sc.subject.name).toSet().length.toString(),
                  Colors.blue,
                  Icons.book),
              _statCard('Rooms', scheduledRooms.length.toString(), Colors.green,
                  Icons.meeting_room),
              _statCard('Sections', scheduledSections.length.toString(),
                  Colors.orange, Icons.groups),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Live Room Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          scheduledRooms.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No rooms assigned yet.')))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduledRooms.length,
                  itemBuilder: (context, i) {
                    final roomName = scheduledRooms[i];
                    final isOccupied = source.any((sc) =>
                        sc.room.name == roomName &&
                        sc.day == DateTime.now().weekday);
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.meeting_room,
                            color: isOccupied ? Colors.red : Colors.green),
                        title: Text(roomName),
                        subtitle: const Text('Status: Manual Entry Room'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                isOccupied ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOccupied ? 'Occupied' : 'Available',
                            style: TextStyle(
                                color: isOccupied ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
