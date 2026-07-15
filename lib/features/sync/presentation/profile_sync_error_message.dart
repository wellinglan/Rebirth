import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';

String profileSyncErrorMessage(Object error) {
  if (error is SyncAuthenticationRequiredException) return '请先开发登录';
  if (error is SyncDeviceRegistrationRequiredException) {
    return '请先注册当前设备';
  }
  if (error is ApiException) {
    return '无法连接开发后端，本地资料未受影响';
  }
  if (error is SyncException) return error.message;
  return 'Profile 同步失败，本地资料未受影响';
}
