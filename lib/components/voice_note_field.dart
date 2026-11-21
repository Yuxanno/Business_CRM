import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_tr.dart';
import '../services/api_client.dart';
import '../services/audio_io.dart';
import '../services/speech_service.dart';
import '../theme/app_colors.dart';
import 'form_widgets.dart';

enum _VoiceState { idle, recording, transcribing }

/// Minimalist text field with built-in Groq Whisper voice dictation
/// restricted to 2 languages: RUS ('ru'), ENG ('en').
class VoiceNoteField extends StatefulWidget {
  const VoiceNoteField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon = Icons.notes_rounded,
    this.minLines,
    this.maxLines = 3,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final int? minLines;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  @override
  State<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends State<VoiceNoteField> {
  static const int _maxSeconds = 60;
  static const String _prefKey = 'bizflow_stt_lang';

  /// Shared across all VoiceNoteField instances so switching language in
  /// "Work description" immediately syncs with "Internal notes".
  static final ValueNotifier<String> _selectedLangNotifier =
      ValueNotifier<String>('ru');
  static bool _langLoaded = false;

  final AudioRecorder _recorder = AudioRecorder();

  _VoiceState _state = _VoiceState.idle;
  int _elapsedSeconds = 0;
  List<double> _bars = [0.22, 0.22, 0.22, 0.22, 0.22];
  String? _inlineError;
  String _mimeType = 'audio/mp4';
  String _ext = 'm4a';

  Timer? _ampTimer;
  Timer? _durationTimer;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _ensureLanguageLoaded();
  }

  Future<void> _ensureLanguageLoaded() async {
    if (_langLoaded) return;
    _langLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'ru' || saved == 'en') {
        _selectedLangNotifier.value = saved!;
      } else {
        _selectedLangNotifier.value = AppTr.isEn ? 'en' : 'ru';
      }
    } catch (_) {}
  }

  Future<void> _setLanguage(String code) async {
    if (code != 'ru' && code != 'en') return;
    HapticFeedback.selectionClick();
    _selectedLangNotifier.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }

  Future<void> _cycleLanguage() async {
    final current = _selectedLangNotifier.value;
    final next = current == 'ru' ? 'en' : 'ru';
    await _setLanguage(next);
  }

  String _labelForLang(String code) => switch (code) {
        'en' => 'ENG',
        _ => 'RUS',
      };

  @override
  void dispose() {
    _stopTimers();
    _errorTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _stopTimers() {
    _ampTimer?.cancel();
    _ampTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _showInlineError(String message) {
    _errorTimer?.cancel();
    if (!mounted) return;
    setState(() => _inlineError = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _inlineError = null);
    });
  }

  Future<(AudioEncoder, String, String)?> _pickEncoder() async {
    final candidates = kIsWeb
        ? const [
            (AudioEncoder.opus, 'audio/webm', 'webm'),
            (AudioEncoder.aacLc, 'audio/mp4', 'm4a'),
            (AudioEncoder.wav, 'audio/wav', 'wav'),
          ]
        : const [
            (AudioEncoder.aacLc, 'audio/mp4', 'm4a'),
            (AudioEncoder.wav, 'audio/wav', 'wav'),
          ];

    for (final c in candidates) {
      try {
        if (await _recorder.isEncoderSupported(c.$1)) {
          return c;
        }
      } catch (_) {}
    }
    return candidates.last;
  }

  Future<void> _startRecording() async {
    if (_state != _VoiceState.idle) return;
    _errorTimer?.cancel();
    setState(() => _inlineError = null);

    try {
      final permitted = await _recorder.hasPermission();
      if (!mounted) return;
      if (!permitted) {
        _showInlineError(
          context.tr('Нет доступа к микрофону', 'Microphone access denied'),
        );
        return;
      }

      final picked = await _pickEncoder();
      if (!mounted || picked == null) return;

      final (encoder, mimeType, ext) = picked;
      _mimeType = mimeType;
      _ext = ext;

      final config = RecordConfig(
        encoder: encoder,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      );

      final path = await createTempAudioPath(ext);
      await _recorder.start(config, path: path);
      if (!mounted) {
        unawaited(_recorder.stop());
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() {
        _state = _VoiceState.recording;
        _elapsedSeconds = 0;
        _bars = [0.22, 0.22, 0.22, 0.22, 0.22];
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _state != _VoiceState.recording) return;
        setState(() => _elapsedSeconds += 1);
        if (_elapsedSeconds >= _maxSeconds) {
          unawaited(_stopAndTranscribe());
        }
      });

      _ampTimer = Timer.periodic(const Duration(milliseconds: 90), (_) async {
        if (!mounted || _state != _VoiceState.recording) return;
        try {
          final amp = await _recorder.getAmplitude();
          if (!mounted || _state != _VoiceState.recording) return;
          final level = ((amp.current + 55.0) / 55.0).clamp(0.18, 1.0);
          setState(() {
            _bars = [..._bars.sublist(1), level];
          });
        } catch (_) {}
      });
    } catch (e) {
      _stopTimers();
      if (mounted) {
        setState(() => _state = _VoiceState.idle);
        _showInlineError(
          context.tr(
            'Не удалось запустить запись',
            'Could not start recording',
          ),
        );
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (_state != _VoiceState.recording) return;
    _stopTimers();
    HapticFeedback.selectionClick();
    setState(() => _state = _VoiceState.transcribing);

    try {
      final path = await _recorder.stop();
      if (!mounted) return;

      if (path == null || path.isEmpty) {
        setState(() => _state = _VoiceState.idle);
        _showInlineError(
          context.tr('Запись не сохранилась', 'Recording failed'),
        );
        return;
      }

      final bytes = await readRecordedAudioBytes(path);
      if (!mounted) return;

      if (bytes.length < 1000) {
        setState(() => _state = _VoiceState.idle);
        _showInlineError(
          context.tr(
            'Запись слишком короткая — попробуйте ещё раз',
            'Recording is too short — please try again',
          ),
        );
        return;
      }

      final result = await SpeechService.transcribe(
        bytes: bytes,
        mimeType: _mimeType,
        filename: 'note.$_ext',
        language: _selectedLangNotifier.value,
      );
      if (!mounted) return;

      setState(() => _state = _VoiceState.idle);

      if (result.text.isEmpty || result.noSpeech) {
        _showInlineError(
          context.tr('Речь не распознана', 'No speech detected'),
        );
        return;
      }

      _appendTranscribedText(result.text);
      HapticFeedback.lightImpact();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _state = _VoiceState.idle);
        _showInlineError(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _state = _VoiceState.idle);
        _showInlineError(
          context.tr(
            'Не удалось распознать речь',
            'Could not transcribe speech',
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_state != _VoiceState.recording) return;
    _stopTimers();
    HapticFeedback.selectionClick();
    setState(() => _state = _VoiceState.idle);
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        await deleteRecordedAudio(path);
      }
    } catch (_) {}
  }

  void _appendTranscribedText(String text) {
    final existing = widget.controller.text;
    final String next;
    if (existing.isEmpty) {
      next = text;
    } else if (existing.endsWith(' ') || existing.endsWith('\n')) {
      next = '$existing$text';
    } else {
      next = '$existing $text';
    }
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildTrailingControls(AppSemanticColors colors) {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedLangNotifier,
      builder: (context, currentLang, _) {
        final langChip = GestureDetector(
          onTap: _state == _VoiceState.transcribing ? null : _cycleLanguage,
          behavior: HitTestBehavior.opaque,
          child: Tooltip(
            message: context.tr(
              'Язык речи: RUS / ENG',
              'Speech language: RUS / ENG',
            ),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                _labelForLang(currentLang),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        );

        final Widget actionButton;
        switch (_state) {
          case _VoiceState.idle:
            actionButton = GestureDetector(
              onTap: _startRecording,
              behavior: HitTestBehavior.opaque,
              child: Tooltip(
                message: context.tr('Голосовой ввод', 'Voice input'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.mic_none_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            );
          case _VoiceState.recording:
            actionButton = GestureDetector(
              onTap: _stopAndTranscribe,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.expense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.expense.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.stop_rounded,
                  size: 18,
                  color: colors.expense,
                ),
              ),
            );
          case _VoiceState.transcribing:
            actionButton = Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              ),
            );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            langChip,
            const SizedBox(width: 5),
            actionButton,
          ],
        );
      },
    );
  }

  Widget _buildStatusBar(AppSemanticColors colors) {
    if (_state == _VoiceState.idle) {
      return const SizedBox.shrink();
    }

    if (_state == _VoiceState.transcribing) {
      return ValueListenableBuilder<String>(
        valueListenable: _selectedLangNotifier,
        builder: (context, currentLang, _) {
          return Container(
            height: 38,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  context.tr(
                    'Распознавание (${_labelForLang(currentLang)})...',
                    'Transcribing (${_labelForLang(currentLang)})...',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Recording state with inline 3-language selector (UZB | RUS | ENG)
    return ValueListenableBuilder<String>(
      valueListenable: _selectedLangNotifier,
      builder: (context, currentLang, _) {
        return Container(
          height: 38,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: colors.expense.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colors.expense,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _bars.map((level) {
                  final h = 5.0 + (level * 13.0);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 85),
                    width: 2.5,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    decoration: BoxDecoration(
                      color: colors.expense.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 7),
              Text(
                _formatTimer(_elapsedSeconds),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // 3-language quick pills (UZB / RUS / ENG)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: SpeechService.supportedLanguages.map((item) {
                  final code = item.$1;
                  final label = item.$2;
                  final active = currentLang == code;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => _setLanguage(code),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? colors.primary
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? Colors.white
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cancelRecording,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: _stopAndTranscribe,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        context.tr('Готово', 'Done'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormTextField(
          controller: widget.controller,
          prefixIcon: widget.prefixIcon,
          hint: widget.hint,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          focusNode: widget.focusNode,
          trailing: _buildTrailingControls(colors),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _buildStatusBar(colors),
        ),
        if (_inlineError != null) FormFieldError(text: _inlineError!),
      ],
    );
  }
}
