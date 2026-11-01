import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String cloudName = 'ilspinlc';
const String uploadPreset = 'iv8sp5an';

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;

  CloudinaryUploadResult({required this.secureUrl, required this.publicId});
}

Future<CloudinaryUploadResult?> uploadImageToCloudinary(File imageFile) async {
  final url = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
  );

  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  final response = await request.send();
  final resBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = jsonDecode(resBody);

    return CloudinaryUploadResult(
      secureUrl: data['secure_url'] as String,
      publicId: data['public_id'] as String,
    );
  }

  print('Cloudinary upload failed: $resBody');
  return null;
}