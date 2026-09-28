import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_departments.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final String role;
  final String department;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.role,
    required this.department,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.card(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: AppGradients.primary,
      borderRadius: AppDecorations.radius(AppRadii.xl),
      borderColor: Colors.transparent,
      boxShadow: context.isDark ? const [] : AppShadows.floating,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('dashboard.welcome_user', args: [userName]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizedRoleLabel(role),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          if (department.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tr(AppDepartments.labelKey(department)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
