import '../../../core/network/api_client.dart';

class TeamService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> createTeam(
    String name, {
    String? description,
  }) async {
    final response = await _api.post(
      '/teams',
      data: {'name': name, 'description': description},
    );
    return response.data;
  }

  Future<void> inviteToTeam(int teamId, String email) async {
    await _api.post('/teams/$teamId/invite', data: {'email': email});
  }

  Future<Map<String, dynamic>> getTeamDetails(int teamId) async {
    final response = await _api.get('/teams/$teamId');
    return response.data;
  }

  Future<void> updateTeam(int teamId, String name, String? description) async {
    await _api.put(
      '/teams/$teamId',
      data: {'name': name, 'description': description},
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

  Future<Map<String, dynamic>> getDashboardData() async {
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

  Future<void> updateTask(int taskId, String title, String? description) async {
    await _api.put(
      '/todos/$taskId',
      data: {'judul': title, 'deskripsi': description},
    );
  }
}
