import 'dart:io';

void main() {
  final dir = Directory('lib/custom_code/widgets');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final regex = RegExp(
      r'return\s+Container\s*\(\s*decoration:\s*const\s*BoxDecoration\s*\(\s*color:\s*Color\(0xFF0D1B2A\),\s*borderRadius:\s*BorderRadius\.vertical\(top:\s*Radius\.circular\(24\)\),\s*\),\s*child:\s*SafeArea',
      multiLine: true);

  final replacement = '''return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea''';

  for (var file in files) {
    var content = file.readAsStringSync();
    if (regex.hasMatch(content)) {
      content = content.replaceAll(regex, replacement);
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
