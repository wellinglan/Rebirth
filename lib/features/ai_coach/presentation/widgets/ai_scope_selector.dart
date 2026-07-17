import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

import '../models/ai_scope_option_model.dart';

class AiScopeSelector extends StatelessWidget {
  const AiScopeSelector({
    required this.selectedScopes,
    required this.onChanged,
    super.key,
  });

  final Set<AiDataScope> selectedScopes;
  final void Function(AiDataScope scope, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('选择本次预览的数据', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '所有范围默认关闭。选择变化后，已有预览会立即清除。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final option in AiScopeCatalog.options) ...[
          Semantics(
            key: ValueKey('aiScopeSemantics-${option.scope.contractValue}'),
            container: true,
            excludeSemantics: true,
            checked: selectedScopes.contains(option.scope),
            enabled: true,
            label: option.accessibilityLabel,
            onTap: () =>
                onChanged(option.scope, !selectedScopes.contains(option.scope)),
            child: Card(
              child: CheckboxListTile(
                key: ValueKey('aiScope-${option.scope.contractValue}'),
                value: selectedScopes.contains(option.scope),
                onChanged: (value) => onChanged(option.scope, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(option.title),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.description),
                      const SizedBox(height: 4),
                      Text('包含：${option.includedFields}'),
                      const SizedBox(height: 4),
                      Text(
                        option.textBoundary,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
