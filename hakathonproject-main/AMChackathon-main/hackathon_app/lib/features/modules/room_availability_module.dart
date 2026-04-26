part of '../../main.dart';

/// Room availability module.
///
/// Displays a simple weekly occupancy grid per room, based on schedule entries.
extension RoomAvailabilityModule on _DashboardScreenState {
  Widget buildRoomAvailabilityModule() {
    final scheduledRoomNames =
        _visibleSchedule.map((sc) => sc.room.name).toSet().toList();
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: scheduledRoomNames.length,
      itemBuilder: (context, i) {
        final roomName = scheduledRoomNames[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Text(roomName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_dayNames.length, (dayIndex) {
                      final dayInt = dayIndex + 1;
                      final isOccupied = _visibleSchedule.any(
                          (sc) => sc.room.name == roomName && sc.day == dayInt);
                      return Container(
                        width: 85,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isOccupied ? Colors.red[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isOccupied
                                  ? Colors.red[200]!
                                  : Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayNames[dayIndex].substring(0, 3),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isOccupied
                                      ? Colors.red[900]
                                      : Colors.green[900]),
                            ),
                            const SizedBox(height: 4),
                            Icon(isOccupied ? Icons.cancel : Icons.check_circle,
                                size: 16,
                                color: isOccupied ? Colors.red : Colors.green),
                            const SizedBox(height: 2),
                            Text(
                              isOccupied ? 'Occupied' : 'Free',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isOccupied
                                      ? Colors.red[700]
                                      : Colors.green[700]),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
