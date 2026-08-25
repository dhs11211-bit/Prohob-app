import 'package:flutter/material.dart';

class SearchableDropdown extends StatefulWidget {
  final String? value;
  final String hint;
  final List<Map<String, String>> items;
  final Function(String?) onChanged;
  final Widget? prefixIcon;

  const SearchableDropdown({
    Key? key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  @override
  Widget build(BuildContext context) {
    String displayLabel = widget.hint;
    if (widget.value != null) {
      final selected =
          widget.items.where((item) => item['value'] == widget.value).toList();
      if (selected.isNotEmpty) {
        displayLabel = selected.first['label'] ?? widget.hint;
      }
    }

    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final offset = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          showDialog(
            context: context,
            useSafeArea: true,
            barrierColor: Colors.transparent,
            builder: (BuildContext dialogContext) {
              String searchQuery = '';
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.black54),
                    ),
                  ),
                  Positioned(
                    top: offset.dy + size.height + 4,
                    left: offset.dx,
                    width: size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredItems = widget.items.where((item) {
                            return (item['label'] ?? '')
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase());
                          }).toList();

                          return Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 4))
                              ],
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    height: 36,
                                    child: TextField(
                                      autofocus: true,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: "Search...",
                                        hintStyle: const TextStyle(
                                            color: Colors.white38),
                                        prefixIcon: const Icon(Icons.search,
                                            color: Colors.white38, size: 16),
                                        filled: true,
                                        fillColor: const Color(0xFF0D1B2A),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 0, horizontal: 12),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() => searchQuery = val);
                                      },
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    thickness: 4,
                                    radius: const Radius.circular(4),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: filteredItems.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredItems[index];
                                        return InkWell(
                                          onTap: () {
                                            Navigator.pop(dialogContext);
                                            widget.onChanged(item['value']);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              border: index <
                                                      filteredItems.length - 1
                                                  ? const Border(
                                                      bottom: BorderSide(
                                                          color:
                                                              Colors.white10))
                                                  : null,
                                            ),
                                            child: Text(
                                              item['label'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: Container(
          height: 41,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  displayLabel,
                  style: TextStyle(
                      color:
                          widget.value == null ? Colors.white38 : Colors.white,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFF3B82F6), size: 20),
            ],
          ),
        ),
      );
    });
  }
}
