class AppConfig {
  // -------------------------------------------------------------------
  // तपाईंको मुख्य डोमेन नाम यहाँ लेख्नुहोस्।
  // क्युआर कोड र अरू सबै लिङ्कहरूले यही ठेगाना प्रयोग गर्नेछन्।
  // -------------------------------------------------------------------
  static const String publicUrl = "startupsgo.tech";

  // protocol (https://)
  static const String protocol = "https";

  // Full URL
  static String get fullBaseUrl => "$protocol://$publicUrl";
}
