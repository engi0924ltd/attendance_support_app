import '../models/attendance.dart';

/// クイックステータスの計算結果
class QuickStatusResult {
  final int scheduled;       // 出勤予定
  final int checkedIn;       // 出勤済
  final int notCheckedIn;    // 未出勤
  final int notRegistered;   // 記録未
  final List<Map<String, dynamic>> notRegisteredUsers;

  const QuickStatusResult({
    required this.scheduled,
    required this.checkedIn,
    required this.notCheckedIn,
    required this.notRegistered,
    required this.notRegisteredUsers,
  });
}

/// クイックステータスを計算する
///
/// [scheduledUsers] - 出勤予定者リスト（バッチAPIから取得）
/// [attendances] - 出勤記録リスト（バッチAPIから取得）
///
/// カウントルール:
/// - 出勤予定: scheduledUsersの人数
/// - 出勤済: attendancesの人数（予定外出勤も含む）
/// - 未出勤: 出勤予定者のうちhasCheckedIn=falseの人数
/// - 記録未: 以下の条件でZ列未入力の人数
///   1. 出勤予定者で出勤済（hasCheckedIn=true）
///   2. 出勤予定者で欠勤・事前連絡あり欠勤
///   3. 予定外出勤者（非利用日など）- ステータス問わず
QuickStatusResult calculateQuickStatus(
  List<Map<String, dynamic>> scheduledUsers,
  List<Attendance> attendances,
) {
  int scheduled = 0;
  int notCheckedIn = 0;
  int notRegistered = 0;
  final notRegisteredUsers = <Map<String, dynamic>>[];
  final scheduledUserNames = <String>{};

  // 1. 出勤予定者のカウント
  for (final user in scheduledUsers) {
    final hasCheckedIn = user['hasCheckedIn'] as bool? ?? false;
    final attendance = user['attendance'] as Attendance?;
    final userName = user['userName'] as String? ?? '';

    scheduled++;
    scheduledUserNames.add(userName);

    if (hasCheckedIn) {
      // 出勤済みで支援記録未入力
      if (attendance != null && !attendance.hasSupportRecord) {
        notRegistered++;
        notRegisteredUsers.add({
          'userName': userName,
          'status': attendance.attendanceStatus ?? '出勤',
          'attendance': attendance,
        });
      }
    } else {
      notCheckedIn++;
      // 欠勤・事前連絡あり欠勤で支援記録未入力もカウント
      if (attendance != null) {
        final status = attendance.attendanceStatus;
        final isAbsent = status == '欠勤' || status == '事前連絡あり欠勤';
        if (isAbsent && !attendance.hasSupportRecord) {
          notRegistered++;
          notRegisteredUsers.add({
            'userName': userName,
            'status': status,
            'attendance': attendance,
          });
        }
      }
    }
  }

  // 2. 予定外（非利用日など）で支援記録がある人の記録未もカウント
  // ステータス問わず（出勤・施設外・在宅・欠勤すべて対象）
  for (final attendance in attendances) {
    final userName = attendance.userName ?? '';
    if (!scheduledUserNames.contains(userName)) {
      if (!attendance.hasSupportRecord) {
        notRegistered++;
        notRegisteredUsers.add({
          'userName': userName,
          'status': attendance.attendanceStatus ?? '出勤',
          'attendance': attendance,
        });
      }
    }
  }

  return QuickStatusResult(
    scheduled: scheduled,
    checkedIn: attendances.length,
    notCheckedIn: notCheckedIn,
    notRegistered: notRegistered,
    notRegisteredUsers: notRegisteredUsers,
  );
}
