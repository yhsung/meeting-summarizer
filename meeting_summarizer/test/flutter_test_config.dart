import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() main) async {
  // Enable logging for tests
  await main();
}
