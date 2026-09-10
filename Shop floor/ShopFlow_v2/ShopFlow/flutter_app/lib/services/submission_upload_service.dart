import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Metadata returned after a file upload succeeds.
class UploadedSubmissionFile {
  final String fileName;
  final String fileExtension;
  final String contentType;
  final int fileSizeInBytes;
  final String storagePath;
  final String downloadUrl;

  const UploadedSubmissionFile({
    required this.fileName,
    required this.fileExtension,
    required this.contentType,
    required this.fileSizeInBytes,
    required this.storagePath,
    required this.downloadUrl,
  });
}

/// Handles buyer-side prerequisite file selection and Firebase Storage uploads.
class SubmissionUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Opens the file picker, uploads any file type, and returns metadata.
  Future<UploadedSubmissionFile> pickAndUploadSubmissionFile({
    required String buyerId,
    required String productId,
  }) async {
    // Attempt to pick any file type.
    final pickerResult = await FilePicker.platform.pickFiles(
      allowMultiple: false,

      withData: true,
      type: FileType.any,
    );

    if (pickerResult == null || pickerResult.files.isEmpty) {
      throw StateError('No prerequisite file was selected.');
    }

    final selectedFile = pickerResult.files.single;
    
    // 1. Improved extension detection (handles cases where picker returns null extension)
    String fileExtension = (selectedFile.extension ?? '').trim().toLowerCase();
    if (fileExtension.isEmpty && selectedFile.name.contains('.')) {
      fileExtension = selectedFile.name.split('.').last.toLowerCase();
    }

    // 2. Sanitize IDs and filename to prevent URL/Path breakage
    final cleanBuyerId = buyerId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final cleanProductId = productId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final safeFileName = selectedFile.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    final storagePath = 'submissions/$cleanBuyerId/$cleanProductId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    
    if (kDebugMode) {
      print('Firebase Storage Bucket: ${_storage.bucket}');
      print('Attempting upload to: $storagePath');
    }

    final contentType = _guessContentType(fileExtension);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'buyerId': buyerId,
        'productId': productId,
        'originalFileName': selectedFile.name,
      },
    );

    final storageReference = _storage.ref().child(storagePath);

    try {
      // 3. Prefer putData for better reliability across platforms and network conditions
      if (selectedFile.bytes != null) {
        await storageReference.putData(selectedFile.bytes!, metadata);
      } else if (selectedFile.path != null) {
        await storageReference.putFile(File(selectedFile.path!), metadata);
      } else {
        throw StateError('The selected file data is inaccessible.');
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('Detailed Storage Error: ${e.code} - ${e.message}');
      }
      // If 404 occurs, it usually means the bucket reference in google-services.json is incorrect or inactive
      if (e.code == 'object-not-found' || e.code == 'not-found') {
        throw StateError(
          'Storage error (404): The bucket "${_storage.bucket}" could not be found. '
          'Ensure Firebase Storage is enabled in the console for this project.'
        );
      }
      throw StateError('Upload failed (${e.code}): ${e.message}');
    } catch (e) {
      throw StateError('Could not send this file: $e');
    }

    // Verify file existence by fetching download URL
    final downloadUrl = await storageReference.getDownloadURL();

    return UploadedSubmissionFile(
      fileName: selectedFile.name,
      fileExtension: fileExtension,
      contentType: contentType,
      fileSizeInBytes: selectedFile.size,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  /// Detects content type for images, documents, and other common formats.
  String _guessContentType(String fileExtension) {
    switch (fileExtension) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg':
      case 'img': return 'image/jpeg';
      case 'heic': return 'image/heic';
      case 'heif': return 'image/heif';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }
}
