import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tactical_button.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String installedVersion;
  final int installedBuildNumber;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.installedVersion,
    required this.installedBuildNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required String installedVersion,
    required int installedBuildNumber,
  }) async {
    final isMandatory = updateInfo.isRequired(installedBuildNumber);

    await showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: AppUpdateDialog(
          updateInfo: updateInfo,
          installedVersion: installedVersion,
          installedBuildNumber: installedBuildNumber,
        ),
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadedFilePath;
  String _statusMessage = '';
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startInAppDownload() async {
    final url = widget.updateInfo.apkUrl.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Update package URL is unavailable.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _statusMessage = 'Initializing secure download...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 't69_update_v${widget.updateInfo.latestVersion}_b${widget.updateInfo.buildNumber}.apk';
      final savePath = '${tempDir.path}/$fileName';

      // Delete if already exists to ensure fresh download
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      _cancelToken = CancelToken();
      final dio = Dio();

      await dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            if (total > 0) {
              _progress = received / total;
              final percent = (_progress * 100).toStringAsFixed(0);
              final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
              final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
              _statusMessage = 'Downloading update: $percent% ($receivedMB / $totalMB MB)';
            } else {
              final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
              _statusMessage = 'Downloading: $receivedMB MB received...';
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _downloadedFilePath = savePath;
        _statusMessage = 'Download complete! Launching package installer...';
      });

      // Launch native package installer
      await _launchInstaller(savePath);
    } catch (e) {
      if (!mounted) return;
      if (CancelToken.isCancel(e as dynamic)) return;

      setState(() {
        _isDownloading = false;
        _errorMessage = 'In-app download interrupted. You can retry or download via browser.';
      });
    }
  }

  Future<void> _launchInstaller(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done && mounted) {
        setState(() {
          _statusMessage = 'Tap "Install APK" below to apply the update.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Tap "Install APK" below to apply the update.';
        });
      }
    }
  }

  Future<void> _fallbackBrowserDownload() async {
    final urlStr = widget.updateInfo.apkUrl.trim();
    if (urlStr.isEmpty) return;

    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.updateInfo.isRequired(widget.installedBuildNumber);
    final notesList = widget.updateInfo.updateNotes
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Gradient Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF070E24),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                isMandatory ? 'REQUIRED UPDATE' : 'NEW VERSION',
                                style: AppTextStyles.badge.copyWith(
                                  color: const Color(0xFF00E5FF),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update Available!',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Content Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version Pills
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlueTile,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INSTALLED',
                              style: AppTextStyles.badge.copyWith(
                                fontSize: 8.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${widget.installedVersion} (Build ${widget.installedBuildNumber})',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'LATEST RELEASE',
                              style: AppTextStyles.badge.copyWith(
                                fontSize: 8.5,
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${widget.updateInfo.latestVersion} (Build ${widget.updateInfo.buildNumber})',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // What's New Section (when not downloading)
                  if (!_isDownloading && _downloadedFilePath == null) ...[
                    Text(
                      'WHAT\'S NEW',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: notesList.isNotEmpty
                              ? notesList.map((note) {
                                  final cleanNote = note.replaceFirst(RegExp(r'^[-*•]\s*'), '');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4, right: 8),
                                          child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                                        ),
                                        Expanded(
                                          child: Text(
                                            cleanNote,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textPrimary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList()
                              : [
                                  Text(
                                    widget.updateInfo.updateNotes,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],

                  // In-App Download Progress Area
                  if (_isDownloading || _downloadedFilePath != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _isDownloading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                    )
                                  : const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isDownloading ? 'Downloading Update Package...' : 'Update Downloaded',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE0F2FE),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF0C4A6E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Error Banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF991B1B),
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isMandatory && !_isDownloading) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This update is required to access live lobbies and wallet services.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF991B1B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Action Buttons
                  if (_downloadedFilePath != null) ...[
                    TacticalButton(
                      label: '⚡ INSTALL UPDATE NOW',
                      height: 48,
                      onPressed: () => _launchInstaller(_downloadedFilePath!),
                    ),
                  ] else if (_isDownloading) ...[
                    TacticalButton(
                      label: 'CANCEL DOWNLOAD',
                      variant: TacticalButtonVariant.outline,
                      height: 44,
                      onPressed: () {
                        _cancelToken?.cancel();
                        setState(() {
                          _isDownloading = false;
                          _statusMessage = 'Download cancelled.';
                        });
                      },
                    ),
                  ] else ...[
                    TacticalButton(
                      label: '⚡ UPDATE NOW (ONE TAP)',
                      height: 48,
                      onPressed: _startInAppDownload,
                    ),
                  ],

                  // Fallback browser download option
                  if (!_isDownloading) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isMandatory)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Remind Later',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        TextButton.icon(
                          onPressed: _fallbackBrowserDownload,
                          icon: const Icon(Icons.open_in_browser_rounded, size: 14, color: AppColors.textTertiary),
                          label: Text(
                            'Download via Browser',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
