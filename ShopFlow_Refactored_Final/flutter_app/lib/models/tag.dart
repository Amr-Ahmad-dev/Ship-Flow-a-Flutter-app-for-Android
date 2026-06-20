// lib/models/tag.dart
class AppTag {
  final String tagId;
  final String name;
  final String? parentTagId;
  final int childCount;
  final int productCount;

  const AppTag({
    required this.tagId,
    required this.name,
    this.parentTagId,
    required this.childCount,
    required this.productCount,
  });

  // Constructs an AppTag instance from a JSON-style Map..
  // It provides default values to prevent null pointer exceptions in the UI.
  factory AppTag.fromJson(Map<String, dynamic> j) => AppTag(
        tagId:        j['tagId']        as String? ?? '',
        name:         j['name']         as String? ?? '',
        parentTagId:  j['parentTagId']  as String?,
        childCount:   (j['childCount']  as num?)?.toInt() ?? 0,
        productCount: (j['productCount'] as num?)?.toInt() ?? 0,
      );
}
