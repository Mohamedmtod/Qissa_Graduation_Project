import 'package:flutter/material.dart';

class CustomTextStyle extends StatelessWidget {
  final String text;
  final Color textColor;
  final double fontsize;
  final bool bold;
  final bool semiBold;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow textOverflow;
  final TextDecoration? decoration;
  const CustomTextStyle({
    required this.bold,
    this.semiBold = false ,
    required this.fontsize,
    required this.textColor,
    required this.text,
    this.paddingLeft = 0,
    this.paddingRight = 0,
    this.paddingTop = 0,
    this.paddingBottom = 0,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
    this.textOverflow = TextOverflow.ellipsis,
    this.decoration,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: paddingLeft,
        right: paddingRight,
        top: paddingTop,
        bottom: paddingBottom,
      ),
      child: Text(
        maxLines: maxLines,
        overflow: textOverflow,
        textAlign: textAlign,
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontsize,
          fontWeight: bold
              ? FontWeight.bold
              : (semiBold ? FontWeight.w600 : FontWeight.normal),
          fontFamily: 'Poppins',
          decoration: decoration,
        ),
      ),
    );
  }
}
