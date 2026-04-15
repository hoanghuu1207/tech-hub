import 'package:flutter/material.dart';
import '../utils/index.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double elevation;
  final TextStyle? titleStyle;

  const AppAppBar({
    Key? key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.backgroundColor,
    this.elevation = 0,
    this.titleStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ??
            const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
      ),
      backgroundColor: backgroundColor ?? AppColors.white,
      elevation: elevation,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: actions,
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class AppHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? userName;
  final String? userAvatar;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final int? notificationCount;

  const AppHomeAppBar({
    Key? key,
    this.userName,
    this.userAvatar,
    this.onProfileTap,
    this.onNotificationTap,
    this.notificationCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.sm, bottom: AppSpacing.sm),
        child: GestureDetector(
          onTap: onProfileTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: userAvatar != null
                  ? Image.network(userAvatar!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.person, color: AppColors.surface, size: 20),
                    ),
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TechHub',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.primary,
            ),
          ),
          if (userName != null)
            Text(
              'Xin chào, ${userName?.split(' ').last ?? userName} 👋',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
              ),
            ),
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.softCard,
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.primaryDark, size: 22),
                onPressed: onNotificationTap,
              ),
            ),
            if (notificationCount != null && notificationCount! > 0)
              Positioned(
                top: 8,
                right: AppSpacing.lg + 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: AppColors.discountGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Text(
                    notificationCount! > 9 ? '9+' : notificationCount.toString(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
