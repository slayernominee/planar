import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import '../utils/search/icon_keywords.dart';

class IconPickerDialog extends StatefulWidget {
  final IconData? selectedIcon;

  const IconPickerDialog({super.key, this.selectedIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<MapEntry<String, IconData>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
  }

  void _filterIcons(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        final terms =
            query.toLowerCase().trim().split(' ').where((s) => s.isNotEmpty);

        _searchResults = AppIcons.allIcons.entries.where((entry) {
          final name = entry.key.toLowerCase();
          final keywords = IconKeywords.keywords[entry.key] ?? [];

          return terms.every((term) {
            return name.contains(term) || keywords.any((k) => k.contains(term));
          });
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Select Icon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search icons...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _filterIcons,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                  ? _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No icons found',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) =>
                              _buildIconItem(_searchResults[index]),
                        )
                  : ListView.builder(
                      itemCount: AppIcons.categories.length,
                      itemBuilder: (context, index) {
                        final categoryName =
                            AppIcons.categories.keys.elementAt(index);
                        final categoryIcons = AppIcons.categories.values
                            .elementAt(index)
                            .entries
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 0),
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: categoryIcons.length,
                              itemBuilder: (context, idx) =>
                                  _buildIconItem(categoryIcons[idx]),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIconItem(MapEntry<String, IconData> entry) {
    final isSelected = widget.selectedIcon != null &&
        entry.value.codePoint == widget.selectedIcon!.codePoint;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(entry.value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          entry.value,
          color: isSelected ? Colors.teal : Colors.black87,
          size: 28,
        ),
      ),
    );
  }
}
