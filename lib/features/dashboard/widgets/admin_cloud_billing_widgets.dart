part of '../pages/admin_cloud_billing_page.dart';

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      icon: icon,
      label: label,
      color: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.14),
      showBorder: true,
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final String text;

  const _SectionIntro({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.appTextSecondary,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyBillingText extends StatelessWidget {
  final String text;

  const _EmptyBillingText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.appSurfaceSoft.withValues(
          alpha: context.isDark ? 0.40 : 0.75,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: context.appBorder),
      ),
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.appTextSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppInfoRow(
      icon: icon,
      title: label,
      value: value,
    );
  }
}

class _BillingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String? credits;
  final Color amountColor;

  const _BillingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    this.credits,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.trim().isEmpty
        ? tr('dashboard.billing_uncategorized')
        : title.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.appSurfaceSoft.withValues(
          alpha: context.isDark ? 0.45 : 0.78,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: context.appAccentGradient,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: context.appBorder),
            ),
            child: Icon(
              icon,
              size: 21,
              color: context.appPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  credits == null ? subtitle : '$subtitle • $credits',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            textAlign: TextAlign.end,
            style: context.textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
