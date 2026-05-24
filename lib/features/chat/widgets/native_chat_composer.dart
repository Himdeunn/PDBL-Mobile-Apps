import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import 'native_chat_composer_platform.dart';

class NativeChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool enabled;
  final double height;
  final Widget Function(BuildContext context) fallbackBuilder;

  const NativeChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hintText,
    required this.enabled,
    required this.height,
    required this.fallbackBuilder,
  });

  @override
  State<NativeChatComposer> createState() => _NativeChatComposerState();
}

class _NativeChatComposerState extends State<NativeChatComposer> {
  MethodChannel? _channel;
  bool _updatingFromNative = false;
  String _nativeText = '';
  int _lastMeasuredLength = 0;
  int _lastMeasuredLineBreaks = 0;
  double _height = 44;

  @override
  void initState() {
    super.initState();
    _nativeText = widget.controller.text;
    _lastMeasuredLength = _nativeText.length;
    _lastMeasuredLineBreaks = _lineBreakCount(_nativeText);
    _height = _heightForText(_nativeText);
    widget.controller.addListener(_handleControllerChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NativeChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _nativeText = widget.controller.text;
      _updateHeight(_nativeText);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.enabled != widget.enabled) {
      _channel?.invokeMethod<void>('setEnabled', widget.enabled);
    }
    if (oldWidget.hintText != widget.hintText) {
      _channel?.invokeMethod<void>('setHint', widget.hintText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_updatingFromNative) return;
    final text = widget.controller.text;
    if (text == _nativeText) return;
    _nativeText = text;
    _updateHeight(text);
    _channel?.invokeMethod<void>('setText', text);
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _channel?.invokeMethod<void>('requestFocus');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onChanged') return null;
    final args = Map<Object?, Object?>.from(
      call.arguments as Map<Object?, Object?>,
    );
    final text = args['text'] as String? ?? '';
    final selection = (args['selection'] as int? ?? text.length).clamp(
      0,
      text.length,
    );

    _nativeText = text;
    _updateHeight(text);
    _updatingFromNative = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selection),
    );
    _updatingFromNative = false;
    widget.onChanged(text);
    return null;
  }

  double _heightForText(String text) {
    final explicitLines = text.split('\n').length;
    final wrappedLines = text.isEmpty ? 1 : (text.length / 34).ceil();
    final lines = explicitLines > wrappedLines ? explicitLines : wrappedLines;
    return (24 + lines.clamp(1, 5) * 20).toDouble();
  }

  void _updateHeight(String text) {
    final lineBreaks = _lineBreakCount(text);
    if (text.length == _lastMeasuredLength &&
        lineBreaks == _lastMeasuredLineBreaks) {
      return;
    }
    _lastMeasuredLength = text.length;
    _lastMeasuredLineBreaks = lineBreaks;
    final nextHeight = _heightForText(text);
    if ((nextHeight - _height).abs() < 0.5) return;
    if (!mounted) {
      _height = nextHeight;
      return;
    }
    setState(() => _height = nextHeight);
  }

  int _lineBreakCount(String text) => '\n'.allMatches(text).length;

  Future<void> _handlePlatformViewCreated(int id) async {
    final channel = MethodChannel('wudi/native_chat_composer/$id');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeCall);
    await channel.invokeMethod<void>('setText', widget.controller.text);
    await channel.invokeMethod<void>('setEnabled', widget.enabled);
    await channel.invokeMethod<void>('setHint', widget.hintText);
    if (widget.focusNode.hasFocus) {
      await channel.invokeMethod<void>('requestFocus');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAndroidRuntime) {
      return widget.fallbackBuilder(context);
    }

    return SizedBox(
      height: _height,
      child: AndroidView(
        viewType: 'wudi/native_chat_composer',
        creationParams: {
          'text': widget.controller.text,
          'hint': widget.hintText,
          'enabled': widget.enabled,
          'textColor': AppColors.textPrimary.toARGB32(),
          'hintColor': AppColors.textSecondary.toARGB32(),
          'accentColor': AppColors.calendarSelected.toARGB32(),
          'selectionColor': AppColors.calendarSelected
              .withValues(alpha: 0.26)
              .toARGB32(),
        },
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );
  }
}
