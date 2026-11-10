import 'package:flutter/material.dart';
import '../tokens.dart';
import '../typography.dart';

class DawaFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  const DawaFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DawaRadii.chip),
            border: Border.all(color: DawaColors.border),
            boxShadow: DawaShadows.nav,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSel = i == currentIndex;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(DawaRadii.chip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSel ? item.$2 : item.$1,
                            size: 22,
                            color: isSel ? DawaColors.purple : DawaColors.text2,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            style: DawaTypography.caption(
                              color: isSel ? DawaColors.purple : DawaColors.text2,
                            ).copyWith(
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: DawaDurations.fast,
                            width: isSel ? 16 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: isSel ? DawaColors.purple : Colors.transparent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

