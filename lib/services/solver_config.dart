/// Where the HoDoKu solver lives.
///
/// Kept in one place because the host was previously repeated in two files, and
/// there are two near-identical services deployed on Render — it is easy to
/// point the app at the wrong one and then wonder why the logs are empty.
///
/// Override at build time without editing the source:
///   flutter run --dart-define=SOLVER_HOST=hodokucli.onrender.com
class SolverConfig {
  SolverConfig._();

  /// Points at the Render service that is connected to the GitHub repo and so
  /// actually receives deploys. The older `hodoku-server` service is not wired
  /// to the repo, which is why it kept serving a stale build.
  static const String host = String.fromEnvironment(
    'SOLVER_HOST',
    defaultValue: 'hodokucli.onrender.com',
  );

  static Uri warmup() => Uri.https(host, '/warmup');

  /// The whole solve path for a grid, in one request.
  static Uri solve(String grid) => Uri.https(host, '/solve/$grid');

  /// A single step. Only used against servers that predate /solve.
  static Uri hint(String grid, int step) => Uri.https(host, '/hint/$grid/$step');
}
