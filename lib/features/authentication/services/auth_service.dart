class AuthService {
  // Temporary register function
  Future<bool> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    // Firebase will be added later
    await Future.delayed(
      const Duration(seconds: 2),
    );

    return true;
  }

  // Temporary login function
  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    // Firebase will be added later
    await Future.delayed(
      const Duration(seconds: 2),
    );

    return true;
  }

  // Temporary logout function
  Future<void> logout() async {
    await Future.delayed(
      const Duration(seconds: 1),
    );
  }

  // Temporary password reset
  Future<bool> resetPassword(String email) async {
    await Future.delayed(
      const Duration(seconds: 2),
    );

    return true;
  }
}
