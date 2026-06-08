/// Global configuration constants accessible across all features.
class Config {
  /// Server API base URL (change based on environment)
  static const String serverBaseUrl = 'https://printimate-fb97067bf83c.herokuapp.com';

  static const String printerId= 'printer1'; // Example printer ID for pairing/config
  
  /// Update this when running on a device with a different server IP
  /// Example: 'http://192.168.1.100:3000'
  static const String serverPort = '3000';
}
