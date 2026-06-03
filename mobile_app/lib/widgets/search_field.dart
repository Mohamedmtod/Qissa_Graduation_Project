import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:perfume_app/widgets/icons/search_icon.dart';

class SearchField extends StatefulWidget {
  final double width;
  final double height;

  final String? hintText;
  final int? maxLength;
  final TextEditingController? controller;
  final String? initialValue;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  final bool readOnly;
  final bool autofocus;

  final EdgeInsetsGeometry padding;

  // Styling
  final Color? fillColor;
  final Color? borderColor;
  final double borderRadius;
  final TextStyle? hintStyle;
  final TextStyle? style;
  final Widget? prefixIcon;
  final double fontSize;

  // Layout
  final double horizontalPadding;
  final double iconSize;
  final double gap;

  const SearchField({
    super.key,
    this.width = double.infinity,
    this.height = 80,

    this.hintText,
    this.maxLength,
    this.controller,
    this.initialValue,

    this.onChanged,
    this.onSubmitted,
    this.onTap,

    this.readOnly = false,
    this.autofocus = false,

    this.padding = EdgeInsets.zero,

    this.fillColor,
    this.borderColor,
    this.borderRadius = 12.0,
    this.hintStyle,
    this.style,
    this.prefixIcon,

    this.horizontalPadding = 16,
    this.iconSize = 22,
    this.gap = 8,
    required this.fontSize,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool get _isActive =>
      (!widget.readOnly && _focusNode.hasFocus) || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode(canRequestFocus: !widget.readOnly);

    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cursorStartPadding =
        widget.horizontalPadding + widget.iconSize + widget.gap;

    return Padding(
      padding: widget.padding,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.fillColor ??
              Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!)
              : null,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest
                  .withValues(alpha: 0.09),
              blurRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
            child: GestureDetector(
              onTap: () {
                if (!widget.readOnly && !_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
                widget.onTap?.call();
              },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // 1) The Interactive TextField
                  Center(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: EdgeInsetsDirectional.only(
                        start: _isActive ? cursorStartPadding : widget.horizontalPadding,
                        end: widget.horizontalPadding,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        onTap: widget.onTap,
                        readOnly: widget.readOnly,
                        autofocus: widget.autofocus,
                        maxLines: 1,
                        inputFormatters: [
                          if (widget.maxLength != null)
                            LengthLimitingTextInputFormatter(widget.maxLength),
                        ],
                        style: widget.style ?? TextStyle(fontSize: widget.fontSize , color: Theme.of(context).colorScheme.onSurface),
                        cursorColor: Theme.of(context).colorScheme.primary,

                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),

                  // 2) Animated Hint + Icon
                  IgnorePointer(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: _isActive ? AlignmentDirectional.centerStart : Alignment.center,
                      child: Padding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: widget.horizontalPadding,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: widget.iconSize,
                              height: widget.iconSize,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: widget.prefixIcon ?? const SearchIcon(),
                              ),
                            ),
                            SizedBox(width: widget.gap),

                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _controller.text.isNotEmpty ? 0 : 1,
                              child: Text(
                                widget.hintText ?? '',
                                style:
                                    widget.hintStyle ??
                                    TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: widget.fontSize,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}
