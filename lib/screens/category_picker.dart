import 'package:flutter/material.dart';
import 'package:finman_engine/finman_engine.dart' show allCategories;
import '../sync/sync_service.dart';

/// Bottom-sheet category picker: the general list + "Add new category". Returns the chosen
/// categoryId (creating a custom category first if the user adds one), or null if dismissed.
Future<int?> pickCategory(BuildContext context, SyncService sync, {String? merchant}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryPicker(sync: sync, merchant: merchant),
  );
}

class _CategoryPicker extends StatefulWidget {
  final SyncService sync;
  final String? merchant;
  const _CategoryPicker({required this.sync, this.merchant});
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  bool _adding = false;
  bool _busy = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final id = await widget.sync.addCustomCategory(name);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final cats = allCategories();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.merchant != null ? 'Category for "${widget.merchant}"' : 'Pick a category',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in cats.entries)
              ActionChip(label: Text(e.value), onPressed: () => Navigator.of(context).pop(e.key)),
          ],
        ),
        const Divider(height: 28),
        if (!_adding)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _adding = true),
              icon: const Icon(Icons.add),
              label: const Text('Add new category'),
            ),
          )
        else
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'New category name', isDense: true),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _create, child: const Text('Add')),
          ]),
      ]),
    );
  }
}
