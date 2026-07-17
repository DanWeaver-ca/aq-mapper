import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

/// Per-session settings (group name, device ID, temperature unit) entered
/// once at the start of the lab and attached to every measurement.
class SessionService {
  // Keys are namespaced by storageKey so same-origin deployments (see
  // app_config.dart) keep separate sessions; empty key = original names.
  static final _prefix = storageKey.isEmpty ? '' : '${storageKey}_';
  static final _keyGroupName = '${_prefix}session_group_name';
  static final _keyDeviceId = '${_prefix}session_device_id';
  static final _keyTempUnit = '${_prefix}session_temp_unit';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> get groupName async =>
      (await _prefs).getString(_keyGroupName);

  Future<String?> get deviceId async => (await _prefs).getString(_keyDeviceId);

  Future<String> get tempUnit async =>
      (await _prefs).getString(_keyTempUnit) ?? 'C';

  Future<bool> get isConfigured async {
    final prefs = await _prefs;
    final group = prefs.getString(_keyGroupName);
    final device = prefs.getString(_keyDeviceId);
    return group != null && group.isNotEmpty &&
        device != null && device.isNotEmpty;
  }

  Future<void> save({
    required String groupName,
    required String deviceId,
    required String tempUnit,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyGroupName, groupName);
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyTempUnit, tempUnit);
  }
}
