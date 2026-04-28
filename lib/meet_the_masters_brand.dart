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
  final bool onDark;
  final bool showAmbientGlow;

  const MeetTheMastersLogoBadge({
    super.key,
    this.size = 96,
    this.padding = 14,
    this.onDark = false,
    this.showAmbientGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = size * 1.08;
    final height = size;
    final outerRadius = BorderRadius.circular(size * 0.32);
    final innerRadius = BorderRadius.circular(size * 0.24);
    final shellTop =
        onDark ? Colors.white.withValues(alpha: 0.24) : Colors.white;
    final shellBottom = onDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF0F9FF);
    final innerTop = onDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFF8FCFF);
    final innerBottom = onDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFE0F2FE);
    final borderColor = onDark
        ? Colors.white.withValues(alpha: 0.42)
        : const Color(0xFFD7EAFE);
    const shadowBase = Color(0xFF0F172A);
    final glowColor = onDark ? const Color(0xFF93C5FD) : AppColors.primaryLight;
    final ambientWidth = showAmbientGlow ? size * 0.30 : 0.0;
    final ambientHeight = showAmbientGlow ? size * 0.24 : 0.0;

    return SizedBox(
      width: width + ambientWidth,
      height: height + ambientHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showAmbientGlow)
            Positioned(
              top: height * 0.08,
              child: Container(
                width: width + size * 0.18,
                height: height * 0.68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withValues(alpha: onDark ? 0.22 : 0.12),
                      glowColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            width: width,
            height: height,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: outerRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [shellTop, shellBottom],
              ),
              border: Border.all(
                color: borderColor,
                width: onDark ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowBase.withValues(alpha: onDark ? 0.26 : 0.10),
                  blurRadius: size * 0.34,
                  offset: Offset(0, size * 0.16),
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: onDark ? 0.18 : 0.08),
                  blurRadius: size * 0.56,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: innerRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [innerTop, innerBottom],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: onDark ? 0.12 : 0.78),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: Image.asset(
                  'assets/images/meet_the_masters_logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
