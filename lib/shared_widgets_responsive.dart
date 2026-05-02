// lib/shared_widgets_responsive.dart
// ════════════════════════════════════════════════════════════════════════════
// Responsive Widget Utilities for All Dashboards
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveConstants {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 900;
  static const double desktopMinWidth = 900;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width < desktopMinWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMinWidth;
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }

  static double getVerticalPadding(BuildContext context) {
    if (isMobile(context)) return 12;
    if (isTablet(context)) return 16;
    return 24;
  }
}

/// Responsive action button with loading state
class ResponsiveActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isSmall;
  final double? width;

  const ResponsiveActionButton({
    Key? key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isSmall = false,
    this.width,
  }) : super(key: key);

  @override
  State<ResponsiveActionButton> createState() => _ResponsiveActionButtonState();
}

class _ResponsiveActionButtonState extends State<ResponsiveActionButton> {
  @override
  Widget build(BuildContext context) {

    if (widget.isPrimary) {
      return SizedBox(
        width: widget.width,
        child: ElevatedButton.icon(
          onPressed: widget.isLoading ? null : widget.onPressed,
          icon: widget.isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  widget.icon ?? Icons.check,
                  size: widget.isSmall ? 14 : 16,
                ),
          label: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: widget.isSmall ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSmall ? 12 : 16,
              vertical: widget.isSmall ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: widget.width,
        child: OutlinedButton.icon(
          onPressed: widget.isLoading ? null : widget.onPressed,
          icon: widget.isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : Icon(
                  widget.icon ?? Icons.edit,
                  size: widget.isSmall ? 14 : 16,
                ),
          label: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: widget.isSmall ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSmall ? 12 : 16,
              vertical: widget.isSmall ? 6 : 10,
            ),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }
  }
}

/// Responsive data card
class ResponsiveDataCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const ResponsiveDataCard({
    Key? key,
    required this.title,
    required this.value,
    this.icon,
    this.backgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.sm,
        ),
        padding: EdgeInsets.all(
          ResponsiveConstants.getVerticalPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: ResponsiveConstants.isMobile(context) ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(
                    icon,
                    size: 24,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: ResponsiveConstants.isMobile(context) ? 20 : 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive list item
class ResponsiveListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  const ResponsiveListItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveConstants.isMobile(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(ResponsiveConstants.getVerticalPadding(context)),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 11 : 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty)
                  if (isMobile)
                    PopupMenuButton<int>(
                      itemBuilder: (context) => actions!
                          .asMap()
                          .entries
                          .map((entry) => PopupMenuItem(
                            value: entry.key,
                            child: entry.value,
                          ))
                          .toList(),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive modal/dialog helper
class ResponsiveDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showCloseButton;

  const ResponsiveDialog({
    Key? key,
    required this.title,
    required this.child,
    this.actions,
    this.showCloseButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveConstants.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(
        isMobile ? 16 : 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(
                ResponsiveConstants.getHorizontalPadding(context),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (showCloseButton)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  ResponsiveConstants.getHorizontalPadding(context),
                ),
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(
                  ResponsiveConstants.getVerticalPadding(context),
                ),
                child: isMobile
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for responsive layouts
class ResponsiveSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const ResponsiveSkeletonLoader({
    Key? key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Empty state widget
class ResponsiveEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const ResponsiveEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveConstants.isMobile(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          ResponsiveConstants.getHorizontalPadding(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isMobile ? 48 : 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 13 : 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onActionPressed != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ResponsiveActionButton(
                label: actionLabel ?? 'Try Again',
                icon: Icons.refresh,
                onPressed: onActionPressed!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

