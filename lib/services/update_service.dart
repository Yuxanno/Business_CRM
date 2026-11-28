import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_tr.dart';
import '../theme/app_colors.dart';
import 'api_client.dart';

/// Checks whether a genuinely newer version of BizFlow is published on
/// Google Play (`com.shaloon_dev.bizflow`) or the BizFlow backend (`/api/version`),
/// and prompts the user with a non-blocking update dialog when available.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Fallback compiled version matching `pubspec.yaml` (`1.0.2+3`).
  static const String kFallbackVersion = '1.0.2';
  static const int kFallbackBuildNumber = 3;
  static const String kPackageId = 'com.shaloon_dev.bizflow';
  static const String kPlayStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$kPackageId';

  static const MethodChannel _channel =
      MethodChannel('com.shaloon_dev.bizflow/app_info');

  bool _checkedThisSession = false;
  bool _dialogVisible = false;

  /// Runs at most once per app launch session. Shows an update dialog only if
  /// a strictly newer version is confirmed from the server or Google Play.
  Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    if (_checkedThisSession || _dialogVisible) return;
    _checkedThisSession = true;

    try {
      final localInfo = await _getInstalledVersionInfo();
      final remoteInfo = await _fetchLatestRemoteVersion();
      if (remoteInfo == null) return;

      final isNewer = _isRemoteNewer(
        localVersion: localInfo.version,
        localBuild: localInfo.buildNumber,
        remoteVersion: remoteInfo.version,
        remoteBuild: remoteInfo.buildNumber,
      );

      if (!isNewer || !context.mounted) return;

      await _showUpdateDialog(
        context,
        currentVersion: localInfo.version,
        latestVersion: remoteInfo.version,
        storeUrl: remoteInfo.storeUrl,
      );
    } catch (_) {
      // Never disrupt the user if offline or version check fails.
    }
  }

  Future<_VersionInfo> _getInstalledVersionInfo() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final map = await _channel
            .invokeMapMethod<String, dynamic>('getAppVersion')
            .timeout(const Duration(seconds: 2));
        if (map != null) {
          final v = (map['version'] ?? kFallbackVersion).toString().trim();
          final b = int.tryParse((map['buildNumber'] ?? '').toString()) ??
              kFallbackBuildNumber;
          return _VersionInfo(
            version: v.isEmpty ? kFallbackVersion : v,
            buildNumber: b,
            storeUrl: kPlayStoreWebUrl,
          );
        }
      } catch (_) {}
    }
    return const _VersionInfo(
      version: kFallbackVersion,
      buildNumber: kFallbackBuildNumber,
      storeUrl: kPlayStoreWebUrl,
    );
  }

  Future<_VersionInfo?> _fetchLatestRemoteVersion() async {
    final results = await Future.wait<_VersionInfo?>([
      _fetchFromBackend(),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        _fetchFromPlayStore(),
    ]);

    _VersionInfo? best;
    for (final candidate in results) {
      if (candidate == null) continue;
      if (best == null ||
          _isRemoteNewer(
            localVersion: best.version,
            localBuild: best.buildNumber,
            remoteVersion: candidate.version,
            remoteBuild: candidate.buildNumber,
          )) {
        best = candidate;
      }
    }
    return best;
  }

  Future<_VersionInfo?> _fetchFromBackend() async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/api/version');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final version = (decoded['version'] ?? '').toString().trim();
          final build =
              int.tryParse((decoded['buildNumber'] ?? '').toString()) ?? 0;
          final storeUrl =
              (decoded['storeUrl'] ?? kPlayStoreWebUrl).toString().trim();
          if (_isValidSemver(version)) {
            return _VersionInfo(
              version: version,
              buildNumber: build,
              storeUrl: storeUrl.isEmpty ? kPlayStoreWebUrl : storeUrl,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<_VersionInfo?> _fetchFromPlayStore() async {
    try {
      final uri = Uri.parse('$kPlayStoreWebUrl&hl=en&gl=us');
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final html = response.body;

      final patterns = <RegExp>[
        RegExp(r'\[\[\["([0-9]+\.[0-9]+\.[0-9]+)"\]\]'),
        RegExp(r'"softwareVersion"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"'),
      ];

      for (final regex in patterns) {
        final match = regex.firstMatch(html);
        if (match != null) {
          final version = (match.group(1) ?? '').trim();
          if (_isValidSemver(version)) {
            return _VersionInfo(
              version: version,
              buildNumber: 0,
              storeUrl: kPlayStoreWebUrl,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isValidSemver(String version) {
    return RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(version);
  }

  bool _isRemoteNewer({
    required String localVersion,
    required int localBuild,
    required String remoteVersion,
    required int remoteBuild,
  }) {
    final localParts = _parseVersionParts(localVersion);
    final remoteParts = _parseVersionParts(remoteVersion);

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }

    if (remoteBuild > 0 && localBuild > 0 && remoteBuild > localBuild) {
      return true;
    }
    return false;
  }

  List<int> _parseVersionParts(String version) {
    final cleaned = version.split('+').first.split('-').first.trim();
    final rawParts = cleaned.split('.');
    return List<int>.generate(3, (i) {
      if (i >= rawParts.length) return 0;
      return int.tryParse(rawParts[i]) ?? 0;
    });
  }

  Future<void> _openStore(String storeUrl) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('openStore', {'url': storeUrl});
        return;
      } catch (_) {}
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String storeUrl,
  }) async {
    if (_dialogVisible || !context.mounted) return;
    _dialogVisible = true;

    final colors = context.appColors;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    dialogCtx.tr(
                      'Доступна новая версия',
                      'New update available',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'v$currentVersion  →  v$latestVersion',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dialogCtx.tr(
                      'Вышла новая версия BizFlow с улучшениями стабильности и скорости работы. Рекомендуем обновиться.',
                      'A new version of BizFlow is available with stability and performance improvements. We recommend updating now.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _openStore(storeUrl);
                      },
                      child: Text(
                        dialogCtx.tr('Обновить сейчас', 'Update now'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(
                        dialogCtx.tr('Позже', 'Later'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _dialogVisible = false;
    }
  }
}

class _VersionInfo {
  const _VersionInfo({
    required this.version,
    required this.buildNumber,
    required this.storeUrl,
  });

  final String version;
  final int buildNumber;
  final String storeUrl;
}
