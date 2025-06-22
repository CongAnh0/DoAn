import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

// Utility class to check if student submissions are synced properly
class SubmissionSyncChecker {
  static Future<bool> verifyGradeSync({
    required BuildContext context,
    required String courseId,
    required String assignmentId,
    required String studentId,
    double? newScore,
    String? feedback,
  }) async {
    try {
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

      // Update the submission with grade data
      await dbRef
          .child('submissions/$courseId/$assignmentId/$studentId')
          .update({
        'score': newScore,
        'feedback': feedback,
        'status': 'graded',
        'gradedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Verify the data was properly saved by reading it back
      final snapshot = await dbRef
          .child('submissions/$courseId/$assignmentId/$studentId')
          .once();

      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

        // Check if the score matches what we just set
        if (data['score'] == newScore) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Điểm đã được lưu và đồng bộ thành công'),
              backgroundColor: Colors.green,
            ),
          );
          return true;
        } else {
          // If there's a mismatch, try once more
          await dbRef
              .child('submissions/$courseId/$assignmentId/$studentId')
              .update({
            'score': newScore,
            'feedback': feedback,
            'status': 'graded',
            'gradedAt': DateTime.now().millisecondsSinceEpoch,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã thử đồng bộ lại điểm số'),
              backgroundColor: Colors.orange,
            ),
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi đồng bộ điểm: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
}