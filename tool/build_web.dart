import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Execute este comando na raiz do projeto.');
    exitCode = 1;
    return;
  }

  final match = RegExp(r'^version:\s*([^\s]+)\s*$', multiLine: true)
      .firstMatch(await pubspec.readAsString());
  if (match == null) {
    stderr.writeln('Não foi possível encontrar a versão no pubspec.yaml.');
    exitCode = 1;
    return;
  }

  final version = match.group(1)!;
  final versionFile = File('web/version.json');
  await versionFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'version': version})}\n',
  );
  stdout.writeln('Versão web preparada: $version');

  final result = await Process.start(
    'flutter',
    ['build', 'web', '--release', ...args],
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await result.exitCode;
}
