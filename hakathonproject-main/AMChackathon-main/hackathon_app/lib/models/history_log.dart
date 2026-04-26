import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of actions recorded in the audit trail.
enum ActionType { add, update, delete }

/// One history/audit log entry.
///
/// These documents are written to Firestore by `HistoryService` and displayed
/// in the "History Logs" module for admins.
class HistoryLog {
  final String id;
  final String userId;
  final String userName;
  final ActionType action;
  final String details;
  final DateTime timestamp;

  HistoryLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  /// Serialize this entry into the Firestore-friendly map format.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'action': action.name,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Parse a history log document from Firestore.
  ///
  /// This is defensive against missing fields because logs may be written by
  /// earlier versions of the app.
  factory HistoryLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    final DateTime parsedTime = ts is Timestamp ? ts.toDate() : DateTime.now();
    return HistoryLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      action: ActionType.values.firstWhere((e) => e.name == data['action'],
          orElse: () => ActionType.update),
      details: data['details'] ?? '',
      timestamp: parsedTime,
    );
  }
}
