import 'package:cloud_firestore/cloud_firestore.dart';

/// Small immutable record that is attached to a cart item or order after a
/// seller accepts a prerequisite submission.
class ApprovedPrerequisiteAttachment {
  final String submissionId;
  final String fileName;
  final String fileExtension;
  final String contentType;
  final int fileSizeInBytes;
  final String storagePath;
  final String downloadUrl;
  final DateTime submittedAt;

  const ApprovedPrerequisiteAttachment({
    required this.submissionId,
    required this.fileName,
    required this.fileExtension,
    required this.contentType,
    required this.fileSizeInBytes,
    required this.storagePath,
    required this.downloadUrl,
    required this.submittedAt,
  });

  /// Recreates an attachment from persisted JSON-like data.
  factory ApprovedPrerequisiteAttachment.fromJson(Map<String, dynamic> json) {
    return ApprovedPrerequisiteAttachment(
      submissionId: json['submissionId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'Unnamed file',
      fileExtension: json['fileExtension'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      fileSizeInBytes: (json['fileSizeInBytes'] as num?)?.toInt() ?? 0,
      storagePath: json['storagePath'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      submittedAt: _readDateTime(json['submittedAt']) ?? DateTime.now(),
    );
  }

  /// Converts the attachment into a serializable map for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'submissionId': submissionId,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'contentType': contentType,
      'fileSizeInBytes': fileSizeInBytes,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}

/// Represents the full review workflow for a prerequisite file submission.
class PrerequisiteSubmission {
  final String submissionId;
  final String productId;
  final String productName;
  final String sellerId;
  final String buyerId;
  final String status;
  final String fileName;
  final String fileExtension;
  final String contentType;
  final int fileSizeInBytes;
  final String storagePath;
  final String downloadUrl;
  final String? rejectionMessage;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const PrerequisiteSubmission({
    required this.submissionId,
    required this.productId,
    required this.productName,
    required this.sellerId,
    required this.buyerId,
    required this.status,
    required this.fileName,
    required this.fileExtension,
    required this.contentType,
    required this.fileSizeInBytes,
    required this.storagePath,
    required this.downloadUrl,
    required this.submittedAt,
    this.rejectionMessage,
    this.reviewedAt,
  });

  /// Returns `true` when the seller has not reviewed the file yet.
  bool get isPending => status == 'pending';

  /// Returns `true` when the seller approved the file.
  bool get isAccepted => status == 'accepted';

  /// Returns `true` when the seller rejected the file.
  bool get isRejected => status == 'rejected';

  /// Human-friendly label used by the UI for pills and headings.
  String get statusLabel {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending review';
    }
  }

  /// Creates the attachment snapshot that gets stored in a cart item or order.
  ApprovedPrerequisiteAttachment toApprovedAttachment() {
    return ApprovedPrerequisiteAttachment(
      submissionId: submissionId,
      fileName: fileName,
      fileExtension: fileExtension,
      contentType: contentType,
      fileSizeInBytes: fileSizeInBytes,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      submittedAt: submittedAt,
    );
  }

  /// Recreates a submission from Firestore or other JSON-like sources.
  factory PrerequisiteSubmission.fromJson(Map<String, dynamic> json) {
    return PrerequisiteSubmission(
      submissionId: json['submissionId'] as String? ?? json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Unknown product',
      sellerId: json['sellerId'] as String? ?? '',
      buyerId: json['buyerId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      fileName: json['fileName'] as String? ?? 'Unnamed file',
      fileExtension: json['fileExtension'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      fileSizeInBytes: (json['fileSizeInBytes'] as num?)?.toInt() ?? 0,
      storagePath: json['storagePath'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      rejectionMessage: json['rejectionMessage'] as String?,
      submittedAt: _readDateTime(json['submittedAt']) ?? DateTime.now(),
      reviewedAt: _readDateTime(json['reviewedAt']),
    );
  }

  /// Converts the submission into a serializable shape for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'submissionId': submissionId,
      'productId': productId,
      'productName': productName,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'status': status,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'contentType': contentType,
      'fileSizeInBytes': fileSizeInBytes,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'rejectionMessage': rejectionMessage,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
}

/// Normalizes the different date formats returned by Firebase and local maps.
DateTime? _readDateTime(dynamic rawValue) {
  if (rawValue == null) {
    return null;
  }
  if (rawValue is Timestamp) {
    return rawValue.toDate();
  }
  if (rawValue is DateTime) {
    return rawValue;
  }
  if (rawValue is String && rawValue.isNotEmpty) {
    return DateTime.tryParse(rawValue);
  }
  return null;
}
