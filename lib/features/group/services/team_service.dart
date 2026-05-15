import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';

class TeamService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> createTeam(
    String name, {
    String? description,
    int? maxMembers,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      if (maxMembers != null) 'max_members': maxMembers,
    };
    final response = await _api.post('/teams', data: data);
    return response.data;
  }

  Future<void> inviteToTeam(int teamId, String email) async {
    await _api.post('/teams/$teamId/invite', data: {'email': email});
  }

  Future<dynamic> getTeamDetails(int teamId) async {
    final response = await _api.get('/teams/$teamId');
    return response.data;
  }

  Future<void> updateTeam(
    int teamId,
    String name,
    String? description, {
    int? maxMembers,
  }) async {
    await _api.put(
      '/teams/$teamId',
      data: {
        'name': name,
        'description': description,
        if (maxMembers != null) 'max_members': maxMembers,
      },
    );
  }

  Future<void> removeMember(int teamId, int userId) async {
    await _api.delete('/teams/$teamId/members/$userId');
  }

  Future<void> banMember(int teamId, int userId) async {
    await _api.post('/teams/$teamId/members/$userId/ban');
  }

  Future<void> acceptInvitation(int teamId) async {
    await _api.post('/teams/$teamId/accept');
  }

  Future<void> declineInvitation(int teamId) async {
    await _api.post('/teams/$teamId/decline');
  }

  Future<dynamic> getDashboardData() async {
    final response = await _api.get('/teams');
    return response.data;
  }

  Future<void> deleteTeam(int teamId) async {
    await _api.delete('/teams/$teamId');
  }

  Future<void> toggleTaskStatus(int taskId, bool isCompleted) async {
    await _api.put('/todos/$taskId', data: {'is_completed': isCompleted});
  }

  Future<void> deleteTask(int taskId) async {
    await _api.delete('/todos/$taskId');
  }

  Future<void> updateTask(
    int taskId,
    String title,
    String? description, {
    DateTime? deadline,
    String? priority,
    List<String>? assignedEmails,
  }) async {
    final Map<String, dynamic> data = {
      'judul': title,
      'deskripsi': description,
    };

    if (deadline != null) {
      data['deadline'] = deadline.toIso8601String();
      data['is_deadline_set'] = true;
    }

    if (priority != null) {
      data['priority'] = priority;
    }

    if (assignedEmails != null) {
      data['assigned_emails'] = assignedEmails;
    }

    await _api.put('/todos/$taskId', data: data);
  }

  Future<Map<String, dynamic>> toggleMemberTaskStatus(
    int taskId, {
    bool force = false,
    String? targetEmail,
  }) async {
    final data = <String, dynamic>{
      if (force) 'force': true,
      if (targetEmail != null && targetEmail.trim().isNotEmpty)
        'target_email': targetEmail.trim(),
    };
    final response = await _api.post(
      '/todos/$taskId/toggle-member',
      data: data.isEmpty ? null : data,
    );
    return response.data;
  }

  Future<void> uploadTeamAvatar(
    int teamId,
    String filePath, {
    String? oldAvatarUrl,
  }) async {
    final filename = filePath.split(Platform.pathSeparator).last;
    final extension = filename.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => MediaType('image', 'png'),
      'gif' => MediaType('image', 'gif'),
      _ => MediaType('image', 'jpeg'),
    };

    final fields = <String, dynamic>{
      'avatar': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: contentType,
      ),
    };
    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      fields['old_avatar'] = oldAvatarUrl;
    }
    final formData = FormData.fromMap(fields);
    await _api.post('/teams/$teamId/avatar', data: formData);
  }

  Future<Map<String, dynamic>> checkEmail(String email) async {
    final response = await _api.get(
      '/users/check-email',
      queryParameters: {'email': email},
    );
    return response.data;
  }
}
