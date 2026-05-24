import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'native_text_input_platform.dart';

class NativeTextInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int minLines;
  final int maxLines;
  final double height;
  final TextStyle? style;
  final Color? hintColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool showUnderline;
  final Color underlineColor;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;
  final int? maxLength;
  final Widget Function(BuildContext context) fallbackBuilder;

  const NativeTextInput({
    super.key,
    required this.controller,
    required this.fallbackBuilder,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.minLines = 1,
    this.maxLines = 1,
    this.height = 48,
    this.style,
    this.hintColor,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius = 14,
    this.showUnderline = false,
    this.underlineColor = AppColors.calendarSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.textAlign = TextAlign.start,
    this.maxLength,
  });

  @override
  State<NativeTextInput> createState() => _NativeTextInputState();
}

class _NativeTextInputState extends State<NativeTextInput> {
  MethodChannel? _channel;
  bool _updatingFromNative = false;
  String _nativeText = '';

  @override
  void initState() {
    super.initState();
    _nativeText = widget.controller.text;
    widget.controller.addListener(_handleControllerChanged);
    widget.focusNode?.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NativeTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _nativeText = widget.controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      widget.focusNode?.addListener(_handleFocusChanged);
    }
    _syncConfig(oldWidget: oldWidget);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.focusNode?.removeListener(_handleFocusChanged);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_updatingFromNative) return;
    final text = widget.controller.text;
    if (text == _nativeText) return;
    _nativeText = text;
    _channel?.invokeMethod<void>('setText', text);
  }

  void _handleFocusChanged() {
    if (widget.focusNode?.hasFocus ?? false) {
      _channel?.invokeMethod<void>('requestFocus');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final text = args['text']?.toString() ?? '';
      final selection =
          (args['selection'] as int?)?.clamp(0, text.length) ?? text.length;
      _nativeText = text;
      _updatingFromNative = true;
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection),
      );
      _updatingFromNative = false;
      widget.onChanged?.call(text);
      return null;
    }
    if (call.method == 'onSubmitted') {
      widget.onSubmitted?.call(_nativeText);
      return null;
    }
    return null;
  }

  Future<void> _handlePlatformViewCreated(int id) async {
    final channel = MethodChannel('wudi/native_text_input/$id');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeCall);
    await channel.invokeMethod<void>('setText', widget.controller.text);
    await _syncConfig();
    if (widget.focusNode?.hasFocus ?? false) {
      await channel.invokeMethod<void>('requestFocus');
    }
  }

  Future<void> _syncConfig({NativeTextInput? oldWidget}) async {
    final channel = _channel;
    if (channel == null) return;

    final updates = <Future<void>>[];
    if (oldWidget == null || oldWidget.enabled != widget.enabled) {
      updates.add(channel.invokeMethod<void>('setEnabled', widget.enabled));
    }
    if (oldWidget == null || oldWidget.hintText != widget.hintText) {
      updates.add(channel.invokeMethod<void>('setHint', widget.hintText ?? ''));
    }
    if (oldWidget == null || oldWidget.obscureText != widget.obscureText) {
      updates.add(
        channel.invokeMethod<void>('setObscureText', widget.obscureText),
      );
    }

    if (updates.isNotEmpty) await Future.wait(updates);
  }

  @override
  Widget build(BuildContext context) {
    if (!isAndroidRuntime) return widget.fallbackBuilder(context);

    final style =
        widget.style ??
        const TextStyle(fontSize: 14, color: AppColors.textPrimary);
    final padding = widget.padding.resolve(Directionality.of(context));
    final input = SizedBox(
      height: widget.height,
      child: AndroidView(
        viewType: 'wudi/native_text_input',
        creationParams: {
          'text': widget.controller.text,
          'hint': widget.hintText ?? '',
          'enabled': widget.enabled,
          'obscureText': widget.obscureText,
          'keyboardType': _keyboardTypeName(widget.keyboardType),
          'textInputAction': _inputActionName(widget.textInputAction),
          'minLines': widget.minLines,
          'maxLines': widget.maxLines,
          'textColor': (style.color ?? AppColors.textPrimary).toARGB32(),
          'hintColor': (widget.hintColor ?? AppColors.textPlaceholder)
              .toARGB32(),
          'textSize': style.fontSize ?? 14,
          'accentColor': AppColors.calendarSelected.toARGB32(),
          'selectionColor': AppColors.calendarSelected
              .withValues(alpha: 0.26)
              .toARGB32(),
          'paddingLeft': padding.left,
          'paddingTop': padding.top,
          'paddingRight': padding.right,
          'paddingBottom': padding.bottom,
          'textAlign': _textAlignName(widget.textAlign),
          if (widget.maxLength != null) 'maxLength': widget.maxLength,
        },
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );

    Widget decorated = input;
    final backgroundColor = widget.backgroundColor;
    if (backgroundColor != null) {
      decorated = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(color: backgroundColor, child: decorated),
      );
    }

    final borderColor = widget.borderColor;
    if (borderColor != null) {
      decorated = Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: borderColor, width: widget.borderWidth),
        ),
        child: decorated,
      );
    }

    if (!widget.showUnderline) return decorated;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: widget.underlineColor, width: 1.4),
        ),
      ),
      child: decorated,
    );
  }

  String _keyboardTypeName(TextInputType type) {
    if (type == TextInputType.emailAddress) return 'email';
    if (type == TextInputType.number) return 'number';
    if (type == TextInputType.phone) return 'phone';
    if (type == TextInputType.multiline) return 'multiline';
    if (type == TextInputType.visiblePassword) return 'visiblePassword';
    return 'text';
  }

  String _inputActionName(TextInputAction action) {
    if (action == TextInputAction.search) return 'search';
    if (action == TextInputAction.send) return 'send';
    if (action == TextInputAction.next) return 'next';
    if (action == TextInputAction.newline) return 'newline';
    return 'done';
  }

  String _textAlignName(TextAlign align) {
    if (align == TextAlign.center) return 'center';
    if (align == TextAlign.right || align == TextAlign.end) return 'end';
    return 'start';
  }
}
