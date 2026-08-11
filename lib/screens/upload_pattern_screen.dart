import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_models.dart';
import '../services/api/api_scope.dart';

const _uploadPatternBackground = Color(0xFFF0F2F6);
const _uploadPatternFontFamily = 'Alimama FangYuanTi VF';
const _uploadPatternFontFallbacks = [
  'PingFang SC',
  'Heiti SC',
  'Microsoft YaHei',
];

/// Figma “我要传图纸”图片选择页。
class UploadPatternScreen extends StatefulWidget {
  final BackendServices? services;

  const UploadPatternScreen({super.key, this.services});

  @override
  State<UploadPatternScreen> createState() => _UploadPatternScreenState();
}

class _UploadPatternScreenState extends State<UploadPatternScreen> {
  BackendServices? _services;
  List<WorkItem> _works = const [];
  List<TemplateSubmissionItem> _pendingReviewSubmissions = const [];
  int? _selectedIndex;
  bool _loadingWorks = true;
  bool _submitting = false;
  String? _worksError;
  int _worksRequestVersion = 0;
  int _submissionsRequestVersion = 0;
  String? _submissionWorkId;
  String? _submissionClientRequestId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = widget.services ?? BackendScope.maybeOf(context);
    if (identical(services, _services) && services != null) return;

    _services = services;
    if (services == null) {
      setState(() {
        _loadingWorks = false;
        _worksError = '图纸服务暂不可用';
      });
      return;
    }
    _loadWorks(services);
    _loadPendingReviewSubmissions(services);
  }

  Future<void> _loadWorks(BackendServices services) async {
    final requestVersion = ++_worksRequestVersion;
    setState(() {
      _loadingWorks = true;
      _worksError = null;
    });
    try {
      final result = await services.works.listWorks();
      if (!mounted ||
          !identical(services, _services) ||
          requestVersion != _worksRequestVersion) {
        return;
      }
      setState(() {
        _works = result.items;
        _loadingWorks = false;
      });
    } catch (_) {
      if (!mounted ||
          !identical(services, _services) ||
          requestVersion != _worksRequestVersion) {
        return;
      }
      setState(() {
        _loadingWorks = false;
        _worksError = '图纸加载失败，请重试';
      });
    }
  }

  Future<void> _loadPendingReviewSubmissions(BackendServices services) async {
    final requestVersion = ++_submissionsRequestVersion;
    try {
      final page = await services.templateSubmissions.list();
      if (!mounted ||
          !identical(services, _services) ||
          requestVersion != _submissionsRequestVersion) {
        return;
      }
      setState(() {
        _pendingReviewSubmissions = page.items
            .where((item) => item.isPending)
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted ||
          !identical(services, _services) ||
          requestVersion != _submissionsRequestVersion) {
        return;
      }
      setState(() => _pendingReviewSubmissions = const []);
    }
  }

  void _selectWork(int index) {
    setState(() {
      if (_selectedIndex != index) {
        _submissionWorkId = null;
        _submissionClientRequestId = null;
      }
      _selectedIndex = index;
    });
  }

  Future<void> _confirmSelection() async {
    final selectedIndex = _selectedIndex;
    final works = _selectableWorks;
    final services = _services;
    if (selectedIndex == null || selectedIndex >= works.length) {
      _showMessage('请选择一张图纸');
      return;
    }
    if (services == null) {
      _showMessage('图纸服务暂不可用');
      return;
    }

    final work = works[selectedIndex];
    final title = work.title.trim().isEmpty ? '我的图纸' : work.title.trim();
    if (title.characters.length > 40) {
      _showMessage('图纸标题最多 40 个字');
      return;
    }

    final clientRequestId = _submissionWorkId == work.workId
        ? _submissionClientRequestId ??= _newUuidV4()
        : _newSubmissionRequestId(work.workId);
    setState(() => _submitting = true);
    try {
      await services.templateSubmissions.submit(
        workId: work.workId,
        title: title,
        description: '',
        clientRequestId: clientRequestId,
      );
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _submissionWorkId = null;
        _submissionClientRequestId = null;
      });
      await _loadPendingReviewSubmissions(services);
      if (!mounted) return;
      _showMessage('已提交，等待审核');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(_submissionErrorMessage(error.code));
    } catch (_) {
      if (!mounted) return;
      _showMessage('提交失败，请重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _newSubmissionRequestId(String workId) {
    _submissionWorkId = workId;
    return _submissionClientRequestId = _newUuidV4();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<WorkItem> get _selectableWorks => _works;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _uploadPatternBackground,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  _UploadPatternNavigationBar(
                    onBackTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _UploadPatternGrid(
                            works: _selectableWorks,
                            loading: _loadingWorks,
                            errorMessage: _worksError,
                            selectedIndex: _selectedIndex,
                            onSelected: _selectWork,
                            onRetry: () {
                              final services = _services;
                              if (services != null) _loadWorks(services);
                            },
                          ),
                          if (!_loadingWorks &&
                              _worksError == null &&
                              _pendingReviewSubmissions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _PendingReviewPatterns(
                              submissions: _pendingReviewSubmissions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _UploadPatternBottomBar(
                    canConfirm:
                        !_submitting &&
                        _selectedIndex != null &&
                        _selectedIndex! < _selectableWorks.length,
                    onConfirm: _confirmSelection,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadPatternNavigationBar extends StatelessWidget {
  final VoidCallback onBackTap;

  const _UploadPatternNavigationBar({required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '返回设置',
            child: InkResponse(
              onTap: onBackTap,
              radius: 24,
              child: const SizedBox(
                width: 80,
                height: 44,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: _UploadPatternBackIcon(),
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '设置',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontFamily: _uploadPatternFontFamily,
                fontFamilyFallback: _uploadPatternFontFallbacks,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 22 / 18,
              ),
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _UploadPatternBackIcon extends StatelessWidget {
  const _UploadPatternBackIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/pin_icon/settings_back.svg');
  }
}

class _UploadPatternGrid extends StatelessWidget {
  final List<WorkItem> works;
  final bool loading;
  final String? errorMessage;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onRetry;

  const _UploadPatternGrid({
    required this.works,
    required this.loading,
    required this.errorMessage,
    required this.selectedIndex,
    required this.onSelected,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('upload-pattern-grid-card'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const SizedBox(
        height: 318,
        child: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final errorMessage = this.errorMessage;
    if (errorMessage != null) {
      return SizedBox(
        height: 318,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: works.length < 9 ? 9 : works.length,
      itemBuilder: (context, index) {
        if (index >= works.length) {
          return _EmptyUploadPatternSlot(index: index);
        }
        return _UploadPatternThumbnail(
          work: works[index],
          selected: selectedIndex == index,
          onTap: () => onSelected(index),
        );
      },
    );

    // A nine-slot grid is square in the Figma design: 16pt white inset on all
    // four sides around a 3×3 grid. Constraining the grid itself to a square
    // prevents its bottom edge from stretching when only placeholders fill it.
    return works.length <= 9 ? AspectRatio(aspectRatio: 1, child: grid) : grid;
  }
}

class _EmptyUploadPatternSlot extends StatelessWidget {
  final int index;

  const _EmptyUploadPatternSlot({required this.index});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('upload-pattern-empty-$index'),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF0F2F6)),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );
  }
}

class _PendingReviewPatterns extends StatelessWidget {
  final List<TemplateSubmissionItem> submissions;

  const _PendingReviewPatterns({required this.submissions});

  @override
  Widget build(BuildContext context) {
    final previewSubmissions = submissions.take(3).toList(growable: false);
    final submittedAt = submissions
        .map((work) => work.createdAt)
        .reduce((latest, value) => latest > value ? latest : value);

    return SizedBox(
      key: const ValueKey('upload-pattern-pending-review'),
      height: 72,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PendingReviewPreviews(
                submissions: previewSubmissions,
                total: submissions.length,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '努力审核中',
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: _uploadPatternFontFamily,
                      fontFamilyFallback: _uploadPatternFontFallbacks,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatSubmittedAt(submittedAt)} 提交',
                    style: const TextStyle(
                      color: Color(0x99000000),
                      fontFamily: _uploadPatternFontFamily,
                      fontFamilyFallback: _uploadPatternFontFallbacks,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingReviewPreviews extends StatelessWidget {
  final List<TemplateSubmissionItem> submissions;
  final int total;

  const _PendingReviewPreviews({
    required this.submissions,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    const previewSize = 40.0;
    const overlap = 10.0;
    final width =
        previewSize + (submissions.length - 1) * (previewSize - overlap);

    return SizedBox(
      width: width,
      height: previewSize,
      child: Stack(
        children: [
          for (var index = 0; index < submissions.length; index++)
            Positioned(
              left: index * (previewSize - overlap),
              child: _PendingReviewPreview(
                submission: submissions[index],
                countLabel:
                    index == submissions.length - 1 &&
                        total > submissions.length
                    ? '+${total - submissions.length + 1}'
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingReviewPreview extends StatelessWidget {
  final TemplateSubmissionItem submission;
  final String? countLabel;

  const _PendingReviewPreview({required this.submission, this.countLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF0F2F6), width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(4.85)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SubmissionThumbnail(submission: submission),
              if (countLabel != null) ...[
                const ColoredBox(color: Color(0x66000000)),
                Center(
                  child: Text(
                    countLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _uploadPatternFontFamily,
                      fontFamilyFallback: _uploadPatternFontFallbacks,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionThumbnail extends StatelessWidget {
  final TemplateSubmissionItem submission;

  const _SubmissionThumbnail({required this.submission});

  @override
  Widget build(BuildContext context) {
    final url = submission.displayImageUrl;
    final uri = Uri.tryParse(url);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (url.isEmpty) {
      return const ColoredBox(color: Color(0xFFF0F2F6));
    }
    if (!isNetworkImage) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF0F2F6)),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF0F2F6)),
    );
  }
}

String _formatSubmittedAt(int secondsSinceEpoch) {
  if (secondsSinceEpoch <= 0) return '刚刚';
  final submittedAt = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch * 1000,
  ).toLocal();
  return '${submittedAt.month.toString().padLeft(2, '0')}.${submittedAt.day.toString().padLeft(2, '0')} '
      '${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';
}

String _submissionErrorMessage(int code) {
  return switch (code) {
    1101 => '图纸信息有误，请检查后重试',
    1102 => '作品已删除，请刷新作品列表',
    1103 => '今天的投稿次数已用完，明天再来吧',
    2004 => '这个作品已经在审核中了',
    _ => '提交失败，请重试',
  };
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class _UploadPatternThumbnail extends StatelessWidget {
  final WorkItem work;
  final bool selected;
  final VoidCallback onTap;

  const _UploadPatternThumbnail({
    required this.work,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '选择${work.title.isEmpty ? '图纸' : work.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          key: ValueKey('upload-pattern-work-${work.workId}'),
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFF0F2F6),
              width: selected ? 2 : 1,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Stack(
              fit: StackFit.expand,
              children: [_WorkThumbnail(work: work)],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkThumbnail extends StatelessWidget {
  final WorkItem work;

  const _WorkThumbnail({required this.work});

  @override
  Widget build(BuildContext context) {
    final url = work.thumbnailUrl.isNotEmpty
        ? work.thumbnailUrl
        : work.patternImageUrl.isNotEmpty
        ? work.patternImageUrl
        : work.originalImageUrl;
    final uri = Uri.tryParse(url);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!isNetworkImage) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF0F2F6)),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF0F2F6)),
    );
  }
}

class _UploadPatternBottomBar extends StatelessWidget {
  final bool canConfirm;
  final VoidCallback onConfirm;

  const _UploadPatternBottomBar({
    required this.canConfirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const ValueKey('upload-pattern-confirm'),
            onPressed: canConfirm ? onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB8BBC2),
              disabledForegroundColor: const Color(0x99FFFFFF),
              elevation: 2,
              shadowColor: const Color(0x1F000000),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: _uploadPatternFontFamily,
                fontFamilyFallback: _uploadPatternFontFallbacks,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('确定上传'),
          ),
        ),
      ),
    );
  }
}
