import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/core_providers.dart';

/// 기록 > 나의 정보 — 동그란 프로필 사진 탭으로 변경.
class ProfileAvatarEditor extends ConsumerStatefulWidget {
  final String? initialAvatarUrl;
  final String displayNameFallback;
  final VoidCallback? onSaved;
  final bool showHint;

  const ProfileAvatarEditor({
    super.key,
    this.initialAvatarUrl,
    required this.displayNameFallback,
    this.onSaved,
    this.showHint = true,
  });

  @override
  ConsumerState<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends ConsumerState<ProfileAvatarEditor> {
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAvatarUrl != widget.initialAvatarUrl) {
      _avatarUrl = widget.initialAvatarUrl;
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploading) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final err = await ref.read(motivationRepositoryProvider).uploadAvatarBytes(bytes);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      final profile = await ref.read(motivationRepositoryProvider).fetchMyProfile();
      if (!mounted) return;
      setState(() => _avatarUrl = profile?.avatarUrl);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진을 저장했어요')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.displayNameFallback.trim();
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _pickAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.secondaryContainer,
                  backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: cs.onSecondaryContainer,
                          ),
                        )
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: _uploading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Icon(Icons.camera_alt_rounded, size: 16, color: cs.onPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.showHint)
            Text(
              '사진을 눌러 프로필을 바꿀 수 있어요',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}
