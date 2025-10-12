import 'package:doc_widget/src/elements.dart';
import 'package:doc_widget/src/styles/colors.dart';
import 'package:doc_widget/src/styles/text.dart';
import 'package:flutter/material.dart';
import 'package:doc_widget/src/styles/spaces.dart';
import 'package:doc_widget/src/widgets/title.dart';

class ItemProperties extends StatelessWidget {
  ItemProperties(this.documentation);

  final Documentation documentation;

  Widget _builderHeader(String name) => Padding(
        padding: const EdgeInsets.all(Spacing.x4),
        child: Text(name, style: TextDS.bodySmallBold()),
      );

  Widget _builderItem({String? name, bool? isActive}) => Padding(
        padding: const EdgeInsets.all(Spacing.x4),
        child: name != null
            ? Text(name, style: TextDS.codeSmall)
            : IgnorePointer(
                child: Checkbox(value: isActive, onChanged: (val) {}),
              ),
      );

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(Spacing.x2));
    double screenWidth = MediaQuery.of(context).size.width;
    List<int> tabFlex = [1, 2, 2, 2, 5];
    return Container(
      width: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextPreview(text: 'Properties'),
          const SizedBox(height: Spacing.x4),
          Table(
            border: TableBorder.all(
              color: ColorsDoc.border,
              borderRadius: borderRadius,
            ),
            columnWidths: tabFlex
                .map((flexValue) => FlexColumnWidth(flexValue.toDouble()))
                .toList()
                .asMap(),
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: ColorsDoc.neutral50,
                  borderRadius: borderRadius,
                ),
                children: [
                  _builderHeader('Required'),
                  _builderHeader('Name'),
                  _builderHeader('Type'),
                  _builderHeader('Default'),
                  _builderHeader('Description'),
                ],
              ),
              ...List.generate(
                documentation.properties.length,
                (index) {
                  final property = documentation.properties[index];
                  return TableRow(
                    children: [
                      _builderItem(isActive: property.isRequired),
                      _builderItem(name: property.name),
                      _builderItem(name: property.type),
                      _builderItem(name: property.defaultValue ?? '-'),
                      _builderItem(name: property.description ?? '-'),
                    ],
                  );
                },
              )
            ],
          ),
          TextPreview(
              text:
                  'Dependencies: ${documentation.dependencies?.join(",") ?? ""}'),
        ],
      ),
    );
  }
}
