abstract class SensitiveDataRepository {
  Future<DecryptedData> decryptData(String encryptedData);
}

class DecryptedData {
  final String type;
  final Map<String, dynamic> data;
  final DateTime? expiresAt;

  const DecryptedData({
    required this.type,
    required this.data,
    this.expiresAt,
  });
}
