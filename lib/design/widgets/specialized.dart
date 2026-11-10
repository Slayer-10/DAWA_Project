import 'package:flutter/material.dart';
import '../tokens.dart';
import '../typography.dart';
import 'components.dart';

/// 12. Medicine Tile
class DawaMedicineTile extends StatelessWidget {
  final String name;
  final String strength;
  final String form;
  final double? minPrice;
  final String? nearestPharmacy;
  final double? distanceKm;
  final VoidCallback? onTap;

  const DawaMedicineTile({
    super.key,
    required this.name,
    required this.strength,
    required this.form,
    this.minPrice,
    this.nearestPharmacy,
    this.distanceKm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DawaColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication_outlined, size: 20, color: DawaColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DawaTypography.section(color: DawaColors.text)),
                    const SizedBox(height: 2),
                    Text(
                      '${strength.isNotEmpty ? "$strength • " : ""}$form',
                      style: DawaTypography.caption(color: DawaColors.text2),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(DawaRadii.chip),
                ),
                child: Text(
                  'In Stock',
                  style: DawaTypography.numeric(size: 11, weight: FontWeight.w700, color: DawaColors.success),
                ),
              ),
            ],
          ),
          if (nearestPharmacy != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 14, color: DawaColors.text2),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$nearestPharmacy ${distanceKm != null ? "(${distanceKm!.toStringAsFixed(1)} km)" : ""}',
                    style: DawaTypography.caption(color: DawaColors.text2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (minPrice != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'from Rs. ${minPrice!.toStringAsFixed(0)}',
                  style: DawaTypography.numeric(size: 14.5, weight: FontWeight.w800, color: DawaColors.purple),
                ),
                Text(
                  'View Stock →',
                  style: DawaTypography.label(color: DawaColors.purple, weight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 13. Pharmacy Card (name, distance, availability)
class DawaPharmacyCard extends StatelessWidget {
  final String name;
  final String address;
  final double? distanceKm;
  final bool isVerified;
  final bool isOpen;
  final VoidCallback? onTap;

  const DawaPharmacyCard({
    super.key,
    required this.name,
    required this.address,
    this.distanceKm,
    this.isVerified = false,
    this.isOpen = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DawaColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_pharmacy_outlined, size: 20, color: DawaColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: DawaTypography.section(color: DawaColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(DawaRadii.chip),
                        ),
                        child: Text(
                          'Verified',
                          style: DawaTypography.caption(color: DawaColors.success),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  address,
                  style: DawaTypography.caption(color: DawaColors.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (distanceKm != null) ...[
                      const Icon(Icons.near_me_outlined, size: 13, color: DawaColors.text2),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm!.toStringAsFixed(1)} km',
                        style: DawaTypography.numeric(size: 12, weight: FontWeight.w600, color: DawaColors.text2),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOpen ? DawaColors.success : DawaColors.text2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'Open Now' : 'Closed',
                      style: DawaTypography.caption(color: isOpen ? DawaColors.success : DawaColors.text2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 14. Confirm Dialog Helper
Future<bool?> showDawaConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DawaRadii.card)),
      title: Text(
        title,
        style: DawaTypography.title(color: isDanger ? DawaColors.danger : DawaColors.text),
      ),
      content: Text(message, style: DawaTypography.body(color: DawaColors.text2)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: DawaTypography.button(color: DawaColors.text2)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDanger ? DawaColors.danger : DawaColors.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel, style: DawaTypography.button(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// 15. Dawa Modal Bottom Sheet Helper
Future<T?> showDawaBottomSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DawaRadii.sheet)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: child,
      ),
    ),
  );
}
