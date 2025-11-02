/// 通过构建参数注入的后端配置项。
/// 使用 `--dart-define` 传入以下键值，例如：
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String supabaseEmailRedirectTo = String.fromEnvironment(
    'SUPABASE_EMAIL_REDIRECT_TO',
    defaultValue: 'https://loopra.vercel.app',
  );

  static const String creemApiKey = String.fromEnvironment(
    'CREEM_API_KEY',
    defaultValue: '',
  );
  static const String creemProductId = String.fromEnvironment(
    'CREEM_PRODUCT_ID',
    defaultValue: '',
  );
  static const String creemApiBaseUrl = String.fromEnvironment(
    'CREEM_API_BASE_URL',
    defaultValue: '',
  );
  static const bool creemSendApiKeyFromClient = bool.fromEnvironment(
    'CREEM_SEND_API_KEY',
    defaultValue: false,
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasCreemConfig =>
      creemApiKey.isNotEmpty || !creemSendApiKeyFromClient;
}
