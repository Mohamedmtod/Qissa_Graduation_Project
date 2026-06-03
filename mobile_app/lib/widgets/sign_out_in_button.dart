import 'package:flutter/material.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';

class SignOutInButton extends StatelessWidget {
  final String hintText;
  final Color hintColor;
  final Color backGroundColor;
  final VoidCallback? onPressed;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final double radius;
  const SignOutInButton({
    required this.hintText,
    required this.hintColor,
    required this.backGroundColor,
    this.onPressed,
    this.paddingLeft = 0,
    this.paddingRight = 0,
    this.paddingTop = 0,
    this.paddingBottom = 0,
    this.radius = 360,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 45,
          maxWidth: 500,
          minHeight: 45,
          minWidth: 500,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backGroundColor,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          child: CustomTextStyle(
            text: hintText,
            textColor: hintColor,
            fontsize: 16,
            bold: true,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
