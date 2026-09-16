import '../../../core/session/session_manager.dart';
import '../domain/repositories/account_repository.dart';
import 'account_remote_data_source.dart';

class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository({
    required AccountRemoteDataSource remote,
    required SessionManager session,
  }) : _remote = remote,
       _session = session;

  final AccountRemoteDataSource _remote;
  final SessionManager _session;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _session.guardTokenRotation(() async {
      final result = await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _session.applyRefreshedSession(result);
    });
  }

  @override
  Future<void> logoutAllDevices() {
    return _session.guardTokenRotation(() async {
      final result = await _remote.logoutAll();
      await _session.applyRefreshedSession(result);
    });
  }

  @override
  Future<void> deleteAccount({required String password}) {
    final userId = _session.currentUserId;
    return _session.guardTokenRotation(() async {
      await _remote.deleteAccount(password: password);
      if (userId != null) {
        await _session.completeAccountDeletion(userId);
      } else {
        await _session.forceLogout(notice: kAccountDeletedNotice);
      }
    });
  }
}
