import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../task/models/task_local.dart';

class WudiSearchBar extends StatelessWidget {
  final List<TaskLocal> tasks;
  final ValueChanged<TaskLocal>? onSelected;

  const WudiSearchBar({super.key, this.tasks = const [], this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<TaskLocal>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) {
          return const Iterable<TaskLocal>.empty();
        }
        return tasks.where((task) {
          return task.title.toLowerCase().contains(query) ||
              (task.description?.toLowerCase().contains(query) ?? false);
        });
      },
      displayStringForOption: (TaskLocal option) => option.title,
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPlaceholder,
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: AppColors.textPlaceholder,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final TaskLocal option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle:
                        option.description != null &&
                            option.description!.isNotEmpty
                        ? Text(
                            option.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: option.teamId != null
                        ? const Icon(
                            Icons.group,
                            size: 16,
                            color: AppColors.primary,
                          )
                        : const Icon(
                            Icons.person,
                            size: 16,
                            color: AppColors.primary,
                          ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
