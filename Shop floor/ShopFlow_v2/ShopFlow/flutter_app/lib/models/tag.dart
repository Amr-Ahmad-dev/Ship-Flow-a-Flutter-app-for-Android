/// Product tag with the number of products currently published under it.
class AppTag {
  final String tagId;
  final String name;
  final int productCount;

  const AppTag({
    required this.tagId,
    required this.name,
    required this.productCount,
  });
}
