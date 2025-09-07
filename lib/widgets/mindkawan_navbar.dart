import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nav_provider.dart';

/// Colors aligned with your capsule AppBar
const _capsule = Color(0xFF0D0D0D);  // same as header background
const _outline = Color(0x22FFFFFF);  // thin light border
const _active = Color(0xFF9F67FF);   // purple accent
const _inactive = Color(0xFFE5E7EB); // light text

class MindKawanNavBar extends ConsumerWidget {
  const MindKawanNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);

    return Semantics(
      label: 'Main navigation',
      child: Container(
        decoration: const BoxDecoration(
          color: _capsule,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.mic_rounded,
                  label: 'Voice Buddy',
                  selected: idx == 0,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  label: 'Mood',
                  selected: idx == 1,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  label: 'Academic',
                  selected: idx == 2,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.self_improvement_rounded,
                  label: 'Relax',
                  selected: idx == 3,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? _active.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(color: _active.withOpacity(0.35))
                      : Border.all(color: Colors.transparent),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: selected ? _active : _inactive,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _active : _inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
