import 'package:flutter/material.dart';
import '../utils/index.dart';

class RatingBar extends StatelessWidget {
  final double rating;
  final int itemCount;
  final double itemSize;
  final Color filledColor;
  final Color emptyColor;
  final bool ignoreGestures;
  final Function(double)? onRatingUpdate;

  const RatingBar({
    Key? key,
    required this.rating,
    this.itemCount = 5,
    this.itemSize = 20,
    this.filledColor = const Color(0xFFFFB800),
    this.emptyColor = AppColors.gray300,
    this.ignoreGestures = true,
    this.onRatingUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        itemCount,
        (index) {
          final isFilled = index < rating.toInt();
          final isHalf = index == rating.toInt() && rating % 1 != 0;

          return GestureDetector(
            onTap: ignoreGestures ? null : () => onRatingUpdate?.call(index + 1.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.star,
                  size: itemSize,
                  color: isFilled ? filledColor : emptyColor,
                ),
                if (isHalf)
                  ClipRect(
                    clipper: _HalfClipper(),
                    child: Icon(
                      Icons.star,
                      size: itemSize,
                      color: filledColor,
                    ),
                  ),
              ],
            ),
          );
        },
      ).expand((widget) {
        return [widget, const SizedBox(width: 4)];
      }).toList()
        ..removeLast(),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
