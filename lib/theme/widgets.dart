import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Reusable building blocks for the Finman design system. Every screen composes these instead of
/// hand-rolling Containers, so spacing, colour and type stay consistent.

/// An eyebrow section label + optional caption, used above every section.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const SectionHeader(this.title, {this.caption, super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppType.sectionLabel),
          if (caption != null)
            Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(caption!, style: AppType.caption)),
          const SizedBox(height: AppSpacing.md),
        ],
      );
}

/// The canonical container: surface fill, 1px border, lg radius, soft shadow. Optional left accent
/// strip (semantic colour) and tap handler.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final VoidCallback? onTap;
  const SectionCard({required this.child, this.padding = AppSpacing.card, this.accent, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: child,
    );
    final card = accent == null
        ? body
        : ClipRRect(
            borderRadius: AppRadius.cardR,
            child: Stack(children: [
              body,
              Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3, color: accent)),
            ]),
          );
    return onTap == null ? card : InkWell(borderRadius: AppRadius.cardR, onTap: onTap, child: card);
  }
}

/// A headline number tile (Income / Expenses / Savings). Tinted fill from a semantic colour.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasize;
  final VoidCallback? onTap;
  const StatTile(
      {required this.label, required this.value, required this.color, this.emphasize = false, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: emphasize ? 0.16 : 0.10), AppColors.surface),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: AppType.sectionLabel.copyWith(color: color.withValues(alpha: 0.9))),
          ),
          if (onTap != null) Icon(Icons.chevron_right, size: 14, color: color.withValues(alpha: 0.7)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppType.moneyLg.copyWith(color: color, fontSize: emphasize ? 30 : 26)),
        ),
      ]),
    );
    return onTap == null ? inner : InkWell(borderRadius: AppRadius.cardR, onTap: onTap, child: inner);
  }
}

/// A colour-dot / label / percent / amount row — used by balances, by-account lists and chart legends.
class LabelledRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? dot;
  final Color? valueColor;
  final bool trailingChevron;
  final VoidCallback? onTap;
  final double? pct;
  const LabelledRow({
    required this.label,
    this.value,
    this.dot,
    this.valueColor,
    this.trailingChevron = false,
    this.onTap,
    this.pct,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
      child: Row(children: [
        if (dot != null) ...[
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: AppType.body)),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Text('${(pct! * 100).round()}%', style: AppType.caption),
          ),
        if (value != null) Text(value!, style: AppType.moneyRow.copyWith(color: valueColor)),
        if (trailingChevron)
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ),
      ]),
    );
    return onTap == null ? row : InkWell(borderRadius: BorderRadius.circular(AppRadius.sm), onTap: onTap, child: row);
  }
}

/// Consistent empty/placeholder state (icon + line + optional sub).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? tint;
  const EmptyState({required this.icon, required this.title, this.subtitle, this.tint, super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(children: [
          Icon(icon, size: 34, color: tint ?? AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: AppType.bodyMuted),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(subtitle!, textAlign: TextAlign.center, style: AppType.caption),
            ),
        ]),
      );
}

/// A tinted attention banner (thin-period notice, needs-category, needs-review). Wraps a row of
/// content in a semantic-coloured card with a leading icon.
class AttentionBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  const AttentionBanner({required this.icon, required this.color, required this.child, this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), AppColors.surface),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: child),
      ]),
    );
    return onTap == null ? inner : InkWell(borderRadius: AppRadius.cardR, onTap: onTap, child: inner);
  }
}
