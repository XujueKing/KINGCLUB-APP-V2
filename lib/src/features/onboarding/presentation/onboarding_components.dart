import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/design_system/king_components.dart';

@immutable
class PreferenceOption {
  const PreferenceOption({required this.id, required this.label});

  final String id;
  final String label;
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.footer,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 85,
        toolbarHeight: 56,
        leading: onBack == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.5,
                  vertical: 4,
                ),
                child: KingBackButton(onPressed: onBack),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: KingColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 27),
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .8)
                      .clamp(0.0, 480.0)
                      .toDouble(),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreferenceSection extends StatelessWidget {
  const PreferenceSection({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<PreferenceOption> options;
  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option.id);
            return FilterChip(
              key: ValueKey('preference-${option.id}'),
              label: Text(option.label, textAlign: TextAlign.center),
              selected: isSelected,
              showCheckmark: false,
              backgroundColor: KingColors.surface,
              selectedColor: KingColors.brandStrong,
              labelStyle: TextStyle(
                color: isSelected
                    ? KingColors.onBrand
                    : KingColors.textSecondary,
                fontSize: 14,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? KingColors.brandStrong : KingColors.border,
                width: isSelected ? 1.2 : 1,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onChanged(option.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}
