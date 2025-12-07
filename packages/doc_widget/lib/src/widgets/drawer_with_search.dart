import 'package:doc_widget/doc_widget.dart';
import 'package:doc_widget/src/styles/colors.dart';
import 'package:doc_widget/src/styles/spaces.dart';
import 'package:doc_widget/src/styles/text.dart';
import 'package:doc_widget/src/utils/platform.dart';
import 'package:doc_widget/src/widgets/drawer.dart';
import 'package:flutter/material.dart';

class DrawerCustom extends StatefulWidget {
  const DrawerCustom({
    required this.sections,
    required this.onTap,
    required this.selectedItem,
    this.title,
  });

  final List<ElementsSection> sections;
  final ValueChanged<ElementPreview> onTap;
  final String? title;
  final ElementPreview selectedItem;

  @override
  State<DrawerCustom> createState() => _DrawerCustomState();
}

class _DrawerCustomState extends State<DrawerCustom> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredSections = _filterSections(widget.sections, searchQuery);

    return Drawer(
      elevation: 2.0,
      backgroundColor: ColorsDoc.white,
      child: Column(
        children: [
          if (isMobile()) const SizedBox(height: kToolbarHeight),

          // TITLE
          Padding(
            padding: EdgeInsets.only(
              top: isMobile() ? Spacing.zero : Spacing.x4,
              left: Spacing.x4,
              right: Spacing.x4,
              bottom: Spacing.x2,
            ),
            child: Text(widget.title ?? 'DocWidget', style: TextDS.heading4),
          ),

          // SEARCH FIELD
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.x4,
              vertical: Spacing.x2,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                searchQuery = value.trim().toLowerCase();
              }),
            ),
          ),

          const SizedBox(height: Spacing.x2),

          // LIST
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: filteredSections
                  .map(
                    (section) => DrawerSection(
                      selectedItem: widget.selectedItem,
                      section: section,
                      onTap: widget.onTap,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // FILTER LOGIC
  List<ElementsSection> _filterSections(
      List<ElementsSection> sections, String query) {
    if (query.isEmpty) return sections;

    return sections
        .map((section) {
          final matchSectionTitle = section.title.toLowerCase().contains(query);

          final filteredElements = section.elements.where((el) {
            final name = el.document.name.toLowerCase();
            return name.contains(query);
          }).toList();

          // Nếu match title → lấy toàn bộ elements
          if (matchSectionTitle && filteredElements.isEmpty) {
            return ElementsSection(
              title: section.title,
              elements: section.elements,
            );
          }

          if (filteredElements.isEmpty) return null;

          return ElementsSection(
            title: section.title,
            elements: filteredElements,
          );
        })
        .where((e) => e != null)
        .cast<ElementsSection>()
        .toList();
  }
}
