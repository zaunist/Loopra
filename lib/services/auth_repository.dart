import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  SupabaseClient get client {
    final SupabaseClient? supabase = _client;
    if (supabase == null) {
      throw StateError('Supabase client is not configured.');
    }
    return supabase;
  }

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  Future<AuthResponse> signUp({required String email, required String password}) {
    return client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }
}
