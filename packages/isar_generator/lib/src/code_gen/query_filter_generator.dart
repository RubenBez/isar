import 'package:isar_generator/src/object_info.dart';
import 'package:dartx/dartx.dart';

class FilterGenerator {
  final ObjectInfo object;
  final String objName;

  FilterGenerator(this.object) : objName = object.dartName;

  String generate() {
    var code =
        'extension ${objName}QueryFilter on QueryBuilder<$objName, $objName, QFilterCondition> {';
    for (var property in object.properties) {
      if (property.nullable) {
        code += generateIsNull(property);
      }

      if (property.isarType != IsarType.bytes) {
        if (!property.isarType.scalarType.isFloatDouble) {
          code += generateEqualTo(property);
        }

        if (property.isarType.scalarType != IsarType.bool) {
          code += generateGreaterThan(property);
          code += generateLessThan(property);
          code += generateBetween(property);
        }

        if (property.isarType.scalarType == IsarType.string) {
          code += generateStringStartsWith(property);
          code += generateStringEndsWith(property);
          code += generateStringContains(property);
          code += generateStringMatches(property);
        }
      }
    }
    return '''
    $code
  }''';
  }

  String caseSensitiveProperty(ObjectProperty p) {
    if (p.isarType == IsarType.string) {
      return '{bool caseSensitive = true,}';
    } else {
      return '';
    }
  }

  String caseSensitiveValue(ObjectProperty p) {
    if (p.isarType == IsarType.string) {
      return 'caseSensitive: caseSensitive,';
    } else {
      return '';
    }
  }

  String vType(ObjectProperty p, [bool nullable = true]) {
    if (p.isarType.isList) {
      return p.isarType.scalarType.dartType(p.nullable && nullable, false);
    } else if (nullable) {
      return p.dartType;
    } else {
      return p.dartType.removeSuffix('?');
    }
  }

  String mPrefix(ObjectProperty p, [bool listAny = true]) {
    final any = listAny && p.isarType.isList ? 'Any' : '';
    return 'QueryBuilder<$objName, $objName, QAfterFilterCondition> ${p.dartName.decapitalize()}$any';
  }

  String toIsar(ObjectProperty p, String name) {
    if (p.converter != null && !p.isarType.isList) {
      return p.toIsar(name, object);
    } else {
      return name;
    }
  }

  String generateEqualTo(ObjectProperty p) {
    return '''
    ${mPrefix(p)}EqualTo(${vType(p)} value, ${caseSensitiveProperty(p)}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.eq,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        ${caseSensitiveValue(p)}
      ));
    }''';
  }

  String generateGreaterThan(ObjectProperty p) {
    return '''
    ${mPrefix(p)}GreaterThan(${vType(p)} value, ${caseSensitiveProperty(p)}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.gt,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        ${caseSensitiveValue(p)}
      ));
    }''';
  }

  String generateLessThan(ObjectProperty p) {
    return '''
    ${mPrefix(p)}LessThan(${vType(p)} value, ${caseSensitiveProperty(p)}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.lt,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        ${caseSensitiveValue(p)}
      ));
    }''';
  }

  String generateBetween(ObjectProperty p) {
    return '''
    ${mPrefix(p)}Between(${vType(p)} lower, ${vType(p)} upper, ${caseSensitiveProperty(p)}) {
      return addFilterCondition(FilterCondition.between(
        property: '${p.dartName}',
        lower: ${toIsar(p, 'lower')},
        upper: ${toIsar(p, 'upper')},
        ${caseSensitiveValue(p)}
      ));
    }''';
  }

  String generateIsNull(ObjectProperty p) {
    var code = '''
    ${mPrefix(p, false)}IsNull() {
      return addFilterCondition(FilterCondition(
        type: ConditionType.isNull,
        property: '${p.dartName}',
        value: null,
      ));
    }''';
    if (p.isarType.isList && p.isarType != IsarType.bytes) {
      code += '''
      ${mPrefix(p)}AnyIsNull() {
        return addFilterCondition(FilterCondition(
          type: ConditionType.eq,
          property: '${p.dartName}',
          value: null,
        ));
      }''';
    }
    return code;
  }

  String generateStringStartsWith(ObjectProperty p) {
    return '''
    ${mPrefix(p)}StartsWith(${vType(p, false)} value, {bool caseSensitive = true}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.startsWith,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        caseSensitive: caseSensitive,
      ));
    }''';
  }

  String generateStringEndsWith(ObjectProperty p) {
    return '''
    ${mPrefix(p)}EndsWith(${vType(p, false)} value, {bool caseSensitive = true}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.endsWith,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        caseSensitive: caseSensitive,
      ));
    }''';
  }

  String generateStringContains(ObjectProperty p) {
    return '''
    ${mPrefix(p)}Contains(${vType(p, false)} value, {bool caseSensitive = true}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.contains,
        property: '${p.dartName}',
        value: ${toIsar(p, 'value')},
        caseSensitive: caseSensitive,
      ));
    }''';
  }

  String generateStringMatches(ObjectProperty p) {
    return '''
    ${mPrefix(p)}Matches(String pattern, {bool caseSensitive = true}) {
      return addFilterCondition(FilterCondition(
        type: ConditionType.matches,
        property: '${p.dartName}',
        value: pattern,
        caseSensitive: caseSensitive,
      ));
    }''';
  }
}
