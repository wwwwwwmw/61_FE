// Local SQLite database has been deprecated in favor of server-side PostgreSQL.
// This stub remains only to avoid refactor breakage where AppDatabase is referenced.
// Remove usages gradually; all persistence now occurs via remote API services.

class AppDatabase {
  const AppDatabase();

  // Throws to indicate local DB is no longer available.
  Future<void> unsupported() async {
    throw UnsupportedError(
      'Local SQLite removed. Use network services instead.',
    );
  }

  // Temporary shim to keep existing code compiling.
  // Returns null and should not be used at runtime.
  dynamic get database => null;
}

/// Minimal stub to satisfy references that previously used `sqflite`.
/// Do not rely on this for real conflict handling.
enum ConflictAlgorithm { ignore, replace }
