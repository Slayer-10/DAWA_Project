import 'package:flutter/material.dart';
import '../tokens.dart';
import '../typography.dart';

/// 1. Primary Button with press-scale feedback, loading and disabled states
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double? width;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.width,
    this.height = 48,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        onPressed: disabled ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DawaColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DawaColors.purple.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DawaRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: widget.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.label, style: DawaTypography.button()),
                ],
              ),
      ),
    );
  }
}

/// 2. Secondary Outline/Tonal Button with press feedback
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double? width;
  final double height;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.width,
    this.height = 48,
    this.color,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final color = widget.color ?? DawaColors.purple;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: OutlinedButton(
        onPressed: disabled ? null : widget.onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color.withValues(alpha: 0.4),
          side: BorderSide(
            color: disabled ? DawaColors.border : color.withValues(alpha: 0.35),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DawaRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: widget.loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: color),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: DawaTypography.button(color: color, weight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 3. Dawa Card (14 radius, border, soft low shadow)
class DawaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const DawaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DawaColors.white,
        borderRadius: BorderRadius.circular(DawaRadii.card),
        border: border ?? Border.all(color: DawaColors.border, width: 1),
        boxShadow: DawaShadows.soft,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DawaRadii.card),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// 4. Dawa Text Field
class DawaTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  const DawaTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: DawaTypography.label(color: DawaColors.text)),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          maxLines: maxLines,
          style: DawaTypography.body(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DawaTypography.body(color: const Color(0xFF9CA3AF)),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: DawaColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DawaRadii.input),
              borderSide: const BorderSide(color: DawaColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DawaRadii.input),
              borderSide: const BorderSide(color: DawaColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DawaRadii.input),
              borderSide: const BorderSide(color: DawaColors.purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// 5. Status Badge (pending/accepted/ready/completed/rejected/cancelled)
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;

    if (s == 'pending' || s == 'order placed' || s == 'awaiting pharmacist verification') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C); // orange
    } else if (s == 'accepted') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB); // blue
    } else if (s == 'ready') {
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED); // purple
    } else if (s == 'completed') {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A); // green
    } else {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626); // red
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DawaRadii.chip),
      ),
      child: Text(
        status.toUpperCase(),
        style: DawaTypography.numeric(size: 11, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// 6. Empty State with clear title, message, and optional action
class DawaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const DawaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: DawaColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: DawaColors.purple),
            ),
            const SizedBox(height: 16),
            Text(title, style: DawaTypography.section(color: DawaColors.text)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: DawaTypography.body(color: DawaColors.text2),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 7. Error State with Retry
class DawaErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DawaErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: DawaColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: DawaTypography.body(color: DawaColors.text2)),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// 8. Skeleton Box for loading shimmer/placeholders
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 9. Price Row & Breakdown
class PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const PriceRow({
    super.key,
    required this.label,
    required this.amount,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? DawaTypography.section(color: DawaColors.text)
              : DawaTypography.body(color: DawaColors.text2),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(0)}',
          style: DawaTypography.numeric(
            size: isTotal ? 17 : 14,
            weight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? DawaColors.purple : DawaColors.text,
          ),
        ),
      ],
    );
  }
}

/// 10. Section Header
class DawaSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const DawaSectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: DawaTypography.section()),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: DawaTypography.caption()),
            ],
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 11. Staggered Fade Slide Entrance (150-300ms, no bounce)
class DawaFadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final double slideOffset;

  const DawaFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: DawaDurations.entrance,
      curve: Curves.easeOut,
      builder: (context, val, ch) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, (1 - val) * slideOffset),
            child: ch,
          ),
        );
      },
      child: child,
    );
  }
}
