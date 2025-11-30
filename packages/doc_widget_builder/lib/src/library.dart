import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:doc_widget_builder/src/utils/regex.dart';
import 'package:doc_widget_builder/src/utils/types.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

String generateLibrary(ClassElement element) {
  final name = element.name;
  final hasState = hasType(element.allSupertypes, 'StatefulWidget');
  final deprecation = getDeprecationMessage(element);
  final snippet = getSnippet(
      removeDocumentationComment(element.documentationComment ?? '') ?? '');
  final emitter = DartEmitter();
  final dartFormatter = DartFormatter();

  final dependencies = _getThirdPartyDependencies(element);

  final getSnippetMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('String')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code(formatSnippet(dartFormatter, snippet, element))
      ..name = 'snippet',
  );

  final getNameMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('String')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code("'$name'")
      ..name = 'name',
  );

  final getHasStateMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('bool')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code('$hasState')
      ..name = 'hasState',
  );

  final getDeprecationMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('String?')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code(deprecation == null ? 'null' : "'$deprecation'")
      ..name = 'deprecation',
  );

  final getPropertiesMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('List<PropertyDoc>')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code('[${_getParametersString(element)}]')
      ..name = 'properties',
  );

  final getDependenciesMethod = Method(
    (m) => m
      ..type = MethodType.getter
      ..returns = refer('List<String>')
      ..lambda = true
      ..annotations.add(refer('override'))
      ..body = Code('[${dependencies.map((e) => "'$e'").join(', ')}]')
      ..name = 'dependencies',
  );

  final classDoc = Class(
    (c) => c
      ..name = '${name}DocWidget'
      ..implements.add(refer('Documentation'))
      ..methods.addAll([
        getNameMethod,
        getHasStateMethod,
        getDeprecationMethod,
        getPropertiesMethod,
        getSnippetMethod,
        getDependenciesMethod,
      ]),
  );

  final importDocs = "import 'package:doc_widget/doc_widget.dart';";

  return dartFormatter.format('$importDocs ${classDoc.accept(emitter)}');
}

String formatSnippet(
  DartFormatter formatter,
  String code,
  ClassElement element,
) {
  try {
    return "'''${formatter.format(code)}'''";
  } catch (e) {
    throw InvalidGenerationSourceError(
      'Snippet code should be valid dart code',
      element: element,
    );
  }
}

void _generateParametersRequired(StringBuffer buffer, ParameterElement param) {
  final name = param.name;
  final isRequired = param.hasRequired || param.isRequired;
  final isNamed = param.isNamed;
  final type = param.type.getDisplayString(withNullability: true);
  buffer.writeln(
    "PropertyDoc(name: '$name', isRequired: $isRequired, isNamed: $isNamed, type: '$type',",
  );
}

String? _convertDartObjectToCode(DartObject? object) {
  if (object == null) return null;
  final values = [
    object.toBoolValue(),
    object.toIntValue(),
    object.toDoubleValue(),
    object.toFunctionValue(),
    object.toListValue(),
    object.toSetValue(),
    object.toMapValue(),
    object.toStringValue(),
    object.toSymbolValue(),
    object.toTypeValue(),
  ];
  return values
      .firstWhere((element) => element != null, orElse: () => null)
      ?.toString();
}

String? getDeprecationMessage(ClassElement element) {
  if (!element.hasDeprecated) return null;
  return element.metadata
      .cast<ElementAnnotation?>()
      .firstWhere(
        (element) => element?.isDeprecated ?? false,
        orElse: () => null,
      )
      ?.computeConstantValue()
      ?.getField('message')
      ?.toStringValue();
}

String? getDefaultValue(ParameterElement param) {
  final paramToString = param.type.getDisplayString(withNullability: true);
  final paramIsString = paramToString.contains('String');
  final defaultValueCode = param.defaultValueCode;

  final defaultComputedValue = param.computeConstantValue();
  final defaultComputedValueCode =
      _convertDartObjectToCode(param.computeConstantValue());

  final isEvaluated = defaultComputedValue?.hasKnownValue == true &&
      (defaultComputedValue?.isNull == true ||
          defaultComputedValueCode != null);

  if (paramIsString) {
    final trimmedValueCode = {'\"', '\''}.contains(defaultValueCode?[0])
        ? defaultValueCode!.substring(1, defaultValueCode.length - 1)
        : defaultValueCode;

    if (trimmedValueCode != defaultComputedValueCode && isEvaluated) {
      return "'$trimmedValueCode: \\'$defaultComputedValueCode\\''";
    } else {
      return defaultValueCode;
    }
  } else {
    if (defaultValueCode != defaultComputedValueCode && isEvaluated) {
      return "'$defaultValueCode: $defaultComputedValueCode'";
    } else {
      return "'$defaultValueCode'";
    }
  }
}

String _getParametersString(ClassElement element) {
  final parameters = element.unnamedConstructor?.parameters ?? [];
  final parametersBuffer = StringBuffer();
  for (final param in parameters) {
    _generateParametersRequired(parametersBuffer, param);

    if (getDescription(param.name, element.fields) != null) {
      final desc = getDescription(param.name, element.fields)!
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '');
      parametersBuffer.write("description: '$desc',");
    }
    if (param.defaultValueCode != null) {
      parametersBuffer.write('defaultValue: ${getDefaultValue(param)},');
    }
    parametersBuffer.write('),');
  }
  return parametersBuffer.toString();
}

String? getDescription(String name, List<FieldElement> fields) {
  final hasField = fields.any((field) => field.name == name);
  if (hasField) {
    final field = fields.firstWhere((element) => element.name == name);
    final hasDocumentation = field.documentationComment != null;
    if (hasDocumentation)
      return hasDocumentation
          ? removeDocumentationComment(field.documentationComment)
          : null;
  }
  return null;
}

List<String> _getThirdPartyDependencies(ClassElement element) {
  final imports = element.library.libraryImports
      .map((e) => e.importedLibrary?.identifier ?? '')
      .where((uri) => uri.startsWith('package:'))
      .where((uri) => !uri.startsWith('package:flutter/'))
      .where((uri) => !uri.startsWith('package:flutter_test/'))
      .where((uri) => !uri.startsWith('package:flutter_web_plugins/'))
      .toList();

  final packages = imports.map(getPackage).whereType<String>().toSet().toList();

  final versions = _readPackageVersions();

  return packages.where(versions.containsKey).map((pkg) {
    final info = versions[pkg]!;
    final prefix = info['type']!;
    final version = info['version'];
    final url = info['url'];
    final path = info['path'];
    final ref = info['ref'];

    // Hosted package: only show version
    final isSpecial = (url != null || path != null || ref != null);

    if (isSpecial) {
      final details = [
        if (url != null) 'url: $url',
        if (path != null) 'path: $path',
        if (ref != null) 'ref: $ref',
      ].join(', ');
      return '$prefix:$pkg: ($details)';
    } else {
      return '$prefix:$pkg: $version';
    }
  }).toList();
}

Map<String, Map<String, String?>> _readPackageVersions() {
  final lockFile = File('pubspec.lock');
  final yamlFile = File('pubspec.yaml');
  if (!lockFile.existsSync() || !yamlFile.existsSync()) return {};
  final lock = loadYaml(lockFile.readAsStringSync()) as YamlMap;
  final yaml = loadYaml(yamlFile.readAsStringSync()) as YamlMap;
  final pkgs = <String, Map<String, String?>>{};
  final deps =
      (yaml['dependencies'] as YamlMap?)?.keys.cast<String>().toSet() ?? {};
  final devDeps =
      (yaml['dev_dependencies'] as YamlMap?)?.keys.cast<String>().toSet() ?? {};

  if (lock['packages'] is YamlMap) {
    (lock['packages'] as YamlMap).forEach((key, value) {
      if (value is! YamlMap) return;
      final source = value['source']?.toString();
      if (source == 'sdk') return;
      if (!(deps.contains(key) || devDeps.contains(key))) return;
      final type = deps.contains(key) ? 'dep' : 'dev';
      final version = value['version']?.toString();
      final desc = value['description'];

      String? url;
      String? path;
      String? ref;

      // FIXED: only read url/path/ref for git or path
      if (desc is YamlMap) {
        if (source == 'git') {
          url = desc['url']?.toString();
          path = desc['path']?.toString();
          ref = desc['ref']?.toString();
        } else if (source == 'path') {
          path = desc['path']?.toString();
        }
      }
      pkgs[key] = {
        'type': type,
        'version': version,
        'url': url,
        'path': path,
        'ref': ref,
      };
    });
  }
  return pkgs;
}
