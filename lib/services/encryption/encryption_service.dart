// Stub — encryption uses Android Keystore, Android only
class EncryptionService {
  EncryptionService();
  Future<void> initialize() async {}
  Future<String> encrypt(List<double> data) async => '';
  Future<List<double>> decrypt(String data) async => [];
}
