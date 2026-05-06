import 'package:finadvise/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MeetTheMastersBrand extends StatelessWidget {
  final String subtitle;
  final bool onDark;
  final double logoSize;
  final double logoPadding;
  final double titleSize;
  final double subtitleSize;
  final double titleLetterSpacing;
  final double gap;
  final String logoAssetPath;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool showAmbientGlow;

  const MeetTheMastersBrand({
    super.key,
    this.subtitle = 'Experience the Experience',
    this.onDark = false,
    this.logoSize = 96,
    this.logoPadding = 14,
    this.titleSize = 22,
    this.subtitleSize = 12,
    this.titleLetterSpacing = 3.2,
    this.gap = 14,
    this.logoAssetPath = 'assets/images/meet_the_masters_logo.png',
    this.titleColor,
    this.subtitleColor,
    this.showAmbientGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitleColor =
        titleColor ?? (onDark ? Colors.white : AppColors.textPrimary);
    final resolvedSubtitleColor = subtitleColor ??
        (onDark
            ? Colors.white.withValues(alpha: 0.82)
            : AppColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MeetTheMastersLogoBadge(
          size: logoSize,
          padding: logoPadding,
          assetPath: logoAssetPath,
          onDark: onDark,
          showAmbientGlow: showAmbientGlow,
        ),
        SizedBox(height: gap),
        Text(
          'MEET THE MASTERS',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: resolvedTitleColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: titleLetterSpacing,
            shadows: onDark
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: resolvedSubtitleColor,
              fontSize: subtitleSize,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class MeetTheMastersLogoBadge extends StatelessWidget {
  final double size;
  final double padding;
  final String assetPath;
  final bool onDark;
  final bool showAmbientGlow;

  const MeetTheMastersLogoBadge({
    super.key,
    this.size = 96,
    this.padding = 14,
    this.assetPath = 'assets/images/meet_the_masters_logo.png',
    this.onDark = false,
    this.showAmbientGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = size;
    final height = size;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}
