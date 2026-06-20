import 'package:flutter/foundation.dart';

// Fallback image shown when a product has no valid image URL.
const _kFallbackImage =
    'https://media.gettyimages.com/id/918291952/photo/ethiopian-jounalist-eskinder-nega-who-was-given-an-18-year-prison-sentence-in-2012-on.jpg?s=612x612&w=0&k=20&c=8A0CFXAlfG18ZO3CwYfVIovT2BN-wGB7SDgeuyRQAlU=';


// Domains that are redirect shortlinks, not direct image hosts.
const _kBlockedHosts = [
  'sl.bing.net',
  'bit.ly',
  'tinyurl.com',
  'goo.gl',
  't.co',
  'ow.ly',
];

// Returns true only for URLs that point to an actual image.
bool _isValidImageUrl(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;

  // Reject known redirect/shortlink domains.
  if (_kBlockedHosts.any((host) => uri.host.contains(host))) return false;

  // Accept known trusted image hosts directly.
  const trustedHosts = [
    'firebasestorage.googleapis.com',
    'images.unsplash.com',
    'res.cloudinary.com',
    'i.imgur.com',
    'ibb.co',
    'i.ibb.co',
  ];
  if (trustedHosts.any((host) => uri.host.contains(host))) return true;

  // For other hosts, require a known image file extension.
  final path = uri.path.toLowerCase();
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif');
}

class Product {
  final String productId;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String tagPath;
  final List<String> tags;
  final String imageUrl;
  final String? sellerId;
  final String expiryDate;
  final bool requiresApproval;
  final List<int> ratings;

  const Product({
    required this.productId,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.tagPath,
    required this.tags,
    required this.expiryDate,
    required this.requiresApproval,
    this.imageUrl = _kFallbackImage,
    this.sellerId,
    this.ratings = const [],
  });

  double get ratingAverage =>
      ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;

  String get tagLabel => tags.isNotEmpty
      ? tags.last
      : (tagPath.isNotEmpty ? tagPath.split('/').last : 'General');

  factory Product.fromJson(Map<String, dynamic> json) {
    final tagPath = json['tagPath'] as String? ?? '';
    final serializedTags =
    (json['tags'] as List?)?.map((e) => e.toString()).toList();
    final derivedTags = tagPath
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Accept imageUrl, image_url, or image field names.
    final rawUrl =
        json['imageUrl'] ?? json['image_url'] ?? json['image'];
    final candidate = (rawUrl as String?)?.trim() ?? '';
    final img = _isValidImageUrl(candidate) ? candidate : _kFallbackImage;

    if (kDebugMode && img == _kFallbackImage && candidate.isNotEmpty) {
      debugPrint(
        'Product "${json['name']}": invalid image URL "$candidate" — '
            'using fallback. Use a direct .jpg/.png URL or Firebase Storage URL.',
      );
    }

    return Product(
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown product',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      tagPath: tagPath,
      tags: serializedTags == null || serializedTags.isEmpty
          ? derivedTags
          : serializedTags,
      imageUrl: img,
      sellerId: json['sellerId'] as String?,
      expiryDate: json['expiryDate'] as String? ?? 'No expiry date',
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      ratings: (json['ratings'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
          [],
    );
  }

  Product copyWith({
    String? productId,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? tagPath,
    List<String>? tags,
    String? imageUrl,
    String? sellerId,
    String? expiryDate,
    bool? requiresApproval,
    List<int>? ratings,
  }) {
    return Product(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      tagPath: tagPath ?? this.tagPath,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      expiryDate: expiryDate ?? this.expiryDate,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      ratings: ratings ?? this.ratings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'tagPath': tagPath,
      'tags': tags,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'expiryDate': expiryDate,
      'requiresApproval': requiresApproval,
      'ratings': ratings,
    };
  }
}