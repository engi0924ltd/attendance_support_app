import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';

/// 利用者管理サービス
class UserService {
  final http.Client _client = http.Client();
  final String? facilityGasUrl; // 施設固有のGAS URL

  UserService({this.facilityGasUrl});

  /// 使用するGAS URLを取得（施設固有 > 保存済み > デフォルト）
  Future<String> get _gasUrl async {
    // コンストラクタで指定されたURLを優先
    if (facilityGasUrl != null && facilityGasUrl!.isNotEmpty) {
      return facilityGasUrl!;
    }

    // 保存された施設のURLを次に優先
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('facility_gas_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }

    // デフォルトURL
    return ApiConfig.baseUrl;
  }

  /// 利用者一覧を取得（契約中 + 退所済み）
  Future<List<User>> getUserList() async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'user/list',
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);

      if (data['success'] == true && data['userList'] != null) {
        final List<dynamic> userListData = data['userList'];
        return userListData.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('利用者一覧取得エラー: $e');
    }
  }

  /// 利用者を新規登録（全60フィールド対応）
  Future<Map<String, dynamic>> createUser({
    // === 基本情報（必須） ===
    required String name,
    required String furigana,
    required String status,
    // === 曜日別出欠予定 ===
    String? scheduledMon,
    String? scheduledTue,
    String? scheduledWed,
    String? scheduledThu,
    String? scheduledFri,
    String? scheduledSat,
    String? scheduledSun,
    // === 連絡先情報 ===
    String? mobilePhone,
    String? chatworkId,
    String? mail,
    String? emergencyContact1,
    String? emergencyPhone1,
    String? emergencyContact2,
    String? emergencyPhone2,
    // === 住所情報 ===
    String? postalCode,
    String? prefecture,
    String? city,
    String? ward,
    String? address,
    String? address2,
    // === 詳細情報 ===
    String? birthDate,
    String? lifeProtection,
    String? disabilityPension,
    String? disabilityNumber,
    String? disabilityGrade,
    String? disabilityType,
    String? handbookValid,
    String? municipalNumber,
    String? certificateNumber,
    String? decisionPeriod1,
    String? decisionPeriod2,
    String? applicableStart,
    String? applicableEnd,
    String? supplyAmount,
    String? supportLevel,
    String? useStartDate,
    // === 期間計算 ===
    String? initialAddition,
    // === 相談支援事業所 ===
    String? consultationFacility,
    String? consultationStaff,
    String? consultationContact,
    // === グループホーム ===
    String? ghFacility,
    String? ghStaff,
    String? ghContact,
    // === その他関係機関 ===
    String? otherFacility,
    String? otherStaff,
    String? otherContact,
    // === 工賃振込先情報 ===
    String? bankName,
    String? bankCode,
    String? branchName,
    String? branchCode,
    String? accountNumber,
    // === 退所・就労情報 ===
    String? leaveDate,
    String? leaveReason,
    String? workName,
    String? workContact,
    String? workContent,
    String? contractType,
    String? employmentSupport,
    String? notes,
  }) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'user/create',
        // 基本情報
        'name': name,
        'furigana': furigana,
        'status': status,
        // 曜日別出欠予定
        'scheduledMon': scheduledMon ?? '',
        'scheduledTue': scheduledTue ?? '',
        'scheduledWed': scheduledWed ?? '',
        'scheduledThu': scheduledThu ?? '',
        'scheduledFri': scheduledFri ?? '',
        'scheduledSat': scheduledSat ?? '',
        'scheduledSun': scheduledSun ?? '',
        // 連絡先情報
        'mobilePhone': mobilePhone ?? '',
        'chatworkId': chatworkId ?? '',
        'mail': mail ?? '',
        'emergencyContact1': emergencyContact1 ?? '',
        'emergencyPhone1': emergencyPhone1 ?? '',
        'emergencyContact2': emergencyContact2 ?? '',
        'emergencyPhone2': emergencyPhone2 ?? '',
        // 住所情報
        'postalCode': postalCode ?? '',
        'prefecture': prefecture ?? '',
        'city': city ?? '',
        'ward': ward ?? '',
        'address': address ?? '',
        'address2': address2 ?? '',
        // 詳細情報
        'birthDate': birthDate ?? '',
        'lifeProtection': lifeProtection ?? '',
        'disabilityPension': disabilityPension ?? '',
        'disabilityNumber': disabilityNumber ?? '',
        'disabilityGrade': disabilityGrade ?? '',
        'disabilityType': disabilityType ?? '',
        'handbookValid': handbookValid ?? '',
        'municipalNumber': municipalNumber ?? '',
        'certificateNumber': certificateNumber ?? '',
        'decisionPeriod1': decisionPeriod1 ?? '',
        'decisionPeriod2': decisionPeriod2 ?? '',
        'applicableStart': applicableStart ?? '',
        'applicableEnd': applicableEnd ?? '',
        'supplyAmount': supplyAmount ?? '',
        'supportLevel': supportLevel ?? '',
        'useStartDate': useStartDate ?? '',
        // 期間計算
        'initialAddition': initialAddition ?? '',
        // 相談支援事業所
        'consultationFacility': consultationFacility ?? '',
        'consultationStaff': consultationStaff ?? '',
        'consultationContact': consultationContact ?? '',
        // グループホーム
        'ghFacility': ghFacility ?? '',
        'ghStaff': ghStaff ?? '',
        'ghContact': ghContact ?? '',
        // その他関係機関
        'otherFacility': otherFacility ?? '',
        'otherStaff': otherStaff ?? '',
        'otherContact': otherContact ?? '',
        // 工賃振込先情報
        'bankName': bankName ?? '',
        'bankCode': bankCode ?? '',
        'branchName': branchName ?? '',
        'branchCode': branchCode ?? '',
        'accountNumber': accountNumber ?? '',
        // 退所・就労情報
        'leaveDate': leaveDate ?? '',
        'leaveReason': leaveReason ?? '',
        'workName': workName ?? '',
        'workContact': workContact ?? '',
        'workContent': workContent ?? '',
        'contractType': contractType ?? '',
        'employmentSupport': employmentSupport ?? '',
        'notes': notes ?? '',
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('利用者登録エラー: $e');
    }
  }

  /// 利用者情報を更新（全60フィールド対応）
  Future<Map<String, dynamic>> updateUser({
    required int rowNumber,
    // === 基本情報（必須） ===
    required String name,
    required String furigana,
    required String status,
    // === 曜日別出欠予定 ===
    String? scheduledMon,
    String? scheduledTue,
    String? scheduledWed,
    String? scheduledThu,
    String? scheduledFri,
    String? scheduledSat,
    String? scheduledSun,
    // === 連絡先情報 ===
    String? mobilePhone,
    String? chatworkId,
    String? mail,
    String? emergencyContact1,
    String? emergencyPhone1,
    String? emergencyContact2,
    String? emergencyPhone2,
    // === 住所情報 ===
    String? postalCode,
    String? prefecture,
    String? city,
    String? ward,
    String? address,
    String? address2,
    // === 詳細情報 ===
    String? birthDate,
    String? lifeProtection,
    String? disabilityPension,
    String? disabilityNumber,
    String? disabilityGrade,
    String? disabilityType,
    String? handbookValid,
    String? municipalNumber,
    String? certificateNumber,
    String? decisionPeriod1,
    String? decisionPeriod2,
    String? applicableStart,
    String? applicableEnd,
    String? supplyAmount,
    String? supportLevel,
    String? useStartDate,
    // === 期間計算 ===
    String? initialAddition,
    // === 相談支援事業所 ===
    String? consultationFacility,
    String? consultationStaff,
    String? consultationContact,
    // === グループホーム ===
    String? ghFacility,
    String? ghStaff,
    String? ghContact,
    // === その他関係機関 ===
    String? otherFacility,
    String? otherStaff,
    String? otherContact,
    // === 工賃振込先情報 ===
    String? bankName,
    String? bankCode,
    String? branchName,
    String? branchCode,
    String? accountNumber,
    // === 退所・就労情報 ===
    String? leaveDate,
    String? leaveReason,
    String? workName,
    String? workContact,
    String? workContent,
    String? contractType,
    String? employmentSupport,
    String? notes,
  }) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'user/update',
        'rowNumber': rowNumber,
        // 基本情報
        'name': name,
        'furigana': furigana,
        'status': status,
        // 曜日別出欠予定
        'scheduledMon': scheduledMon ?? '',
        'scheduledTue': scheduledTue ?? '',
        'scheduledWed': scheduledWed ?? '',
        'scheduledThu': scheduledThu ?? '',
        'scheduledFri': scheduledFri ?? '',
        'scheduledSat': scheduledSat ?? '',
        'scheduledSun': scheduledSun ?? '',
        // 連絡先情報
        'mobilePhone': mobilePhone ?? '',
        'chatworkId': chatworkId ?? '',
        'mail': mail ?? '',
        'emergencyContact1': emergencyContact1 ?? '',
        'emergencyPhone1': emergencyPhone1 ?? '',
        'emergencyContact2': emergencyContact2 ?? '',
        'emergencyPhone2': emergencyPhone2 ?? '',
        // 住所情報
        'postalCode': postalCode ?? '',
        'prefecture': prefecture ?? '',
        'city': city ?? '',
        'ward': ward ?? '',
        'address': address ?? '',
        'address2': address2 ?? '',
        // 詳細情報
        'birthDate': birthDate ?? '',
        'lifeProtection': lifeProtection ?? '',
        'disabilityPension': disabilityPension ?? '',
        'disabilityNumber': disabilityNumber ?? '',
        'disabilityGrade': disabilityGrade ?? '',
        'disabilityType': disabilityType ?? '',
        'handbookValid': handbookValid ?? '',
        'municipalNumber': municipalNumber ?? '',
        'certificateNumber': certificateNumber ?? '',
        'decisionPeriod1': decisionPeriod1 ?? '',
        'decisionPeriod2': decisionPeriod2 ?? '',
        'applicableStart': applicableStart ?? '',
        'applicableEnd': applicableEnd ?? '',
        'supplyAmount': supplyAmount ?? '',
        'supportLevel': supportLevel ?? '',
        'useStartDate': useStartDate ?? '',
        // 期間計算
        'initialAddition': initialAddition ?? '',
        // 相談支援事業所
        'consultationFacility': consultationFacility ?? '',
        'consultationStaff': consultationStaff ?? '',
        'consultationContact': consultationContact ?? '',
        // グループホーム
        'ghFacility': ghFacility ?? '',
        'ghStaff': ghStaff ?? '',
        'ghContact': ghContact ?? '',
        // その他関係機関
        'otherFacility': otherFacility ?? '',
        'otherStaff': otherStaff ?? '',
        'otherContact': otherContact ?? '',
        // 工賃振込先情報
        'bankName': bankName ?? '',
        'bankCode': bankCode ?? '',
        'branchName': branchName ?? '',
        'branchCode': branchCode ?? '',
        'accountNumber': accountNumber ?? '',
        // 退所・就労情報
        'leaveDate': leaveDate ?? '',
        'leaveReason': leaveReason ?? '',
        'workName': workName ?? '',
        'workContact': workContact ?? '',
        'workContent': workContent ?? '',
        'contractType': contractType ?? '',
        'employmentSupport': employmentSupport ?? '',
        'notes': notes ?? '',
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('利用者更新エラー: $e');
    }
  }

  /// 利用者を削除
  Future<Map<String, dynamic>> deleteUser(int rowNumber) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'user/delete',
        'rowNumber': rowNumber,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('利用者削除エラー: $e');
    }
  }

  /// レスポンス処理
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    // 302リダイレクトの場合、リダイレクト先を手動でフォロー
    if (response.statusCode == 302) {
      final redirectMatch =
          RegExp(r'HREF="([^"]+)"').firstMatch(response.body);

      if (redirectMatch != null) {
        final redirectUrl = redirectMatch.group(1)!.replaceAll('&amp;', '&');
        final redirectResponse = await _client
            .get(Uri.parse(redirectUrl))
            .timeout(ApiConfig.timeout);
        return await _handleResponse(redirectResponse);
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'エラーが発生しました');
      }
    } else {
      throw Exception('サーバーエラー: ${response.statusCode}');
    }
  }
}
