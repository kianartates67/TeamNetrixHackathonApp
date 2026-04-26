import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/history_log.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Audit trail helper for user-visible "History Logs".
///
/// The app writes small log entries to Firestore so admins can review actions
/// (add/update/delete) made inside the scheduler UI.
///
/// Storage:
/// - `history_logs` collection in Firestore
/// - most recent 50 logs are streamed for display
class HistoryService {
  static const _coursesCollection = 'courses';
  static const _historyLogsSubcollection = 'history_logs';

  /// Append a new history log record.
  ///
  /// If [userName] / [userId] are not provided, this method will fall back to the
  /// currently authenticated Firebase user (email/uid), then finally to a
  /// "System User" placeholder.
  static Future<void> logAction({
    required ActionType action,
    required String details,
    required String? courseId,
    String? userName,
    String? userId,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;

    // Kung walang pinasa na userName/userId, subukan kunin sa Firebase Auth
    final finalUserName =
        userName ?? authUser?.displayName ?? authUser?.email ?? 'System User';
    final finalUserId = userId ?? authUser?.uid ?? 'system';

    final resolvedCourseId = (courseId ?? '').trim();
    if (resolvedCourseId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection(_coursesCollection)
        .doc(resolvedCourseId)
        .collection(_historyLogsSubcollection)
        .add({
      'userId': finalUserId,
      'userName': finalUserName,
      'action': action.name,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream a small window of recent history logs for the UI.
  ///
  /// The stream automatically updates when new actions are written.
  static Stream<List<HistoryLog>> getLogs({required String? courseId}) {
    final resolvedCourseId = (courseId ?? '').trim();
    if (resolvedCourseId.isEmpty) {
      return const Stream<List<HistoryLog>>.empty();
    }

    return FirebaseFirestore.instance
        .collection(_coursesCollection)
        .doc(resolvedCourseId)
        .collection(_historyLogsSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => HistoryLog.fromFirestore(doc)).toList();
    });
  }
}
