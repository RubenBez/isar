import 'package:isar_generator/src/object_info.dart';
import 'package:dartx/dartx.dart';

String generateObjectAdapter(ObjectInfo object) {
  return '''
    class ${object.adapterName} extends IsarTypeAdapter<${object.dartName}> {

      const ${object.adapterName}();

      ${generateConverterFields(object)}

      ${_generateSerialize(object)}
      ${_generateDeserialize(object)}
      ${_generateDeserializeProperty(object)}
    }
    ''';
}

String generateConverterFields(ObjectInfo object) {
  return object.properties
      .mapNotNull((it) => it.converter)
      .toSet()
      .map((it) => 'static const _$it = $it();')
      .join('\n');
}

String _generatePrepareSerialize(ObjectInfo object) {
  final staticSize = object.staticSize;
  var code = 'var dynamicSize = 0;';
  for (var i = 0; i < object.objectProperties.length; i++) {
    final property = object.objectProperties[i];
    var propertyValue = 'object.${property.dartName}';
    if (property.converter != null) {
      propertyValue = property.toIsar(propertyValue, object);
    }
    code += 'final value$i = $propertyValue;';

    final nOp = property.nullable ? '?' : '';
    final elNOp = property.elementNullable ? '?' : '';
    final nLen = property.nullable ? '?? 0' : '';
    final accessor = '_${property.isarName}';
    switch (property.isarType) {
      case IsarType.string:
        if (property.nullable) {
          code += '''
          Uint8List? $accessor;
          if (value$i != null) {
            $accessor = BinaryWriter.utf8Encoder.convert(value$i);
          }
          ''';
        } else {
          code +=
              'final $accessor = BinaryWriter.utf8Encoder.convert(value$i);';
        }
        code += 'dynamicSize += $accessor$nOp.length $nLen;';
        break;
      case IsarType.stringList:
        code += 'dynamicSize += (value$i$nOp.length $nLen) * 8;';
        if (property.nullable) {
          code += '''
          List<Uint8List?>? bytesList$i;
          if (value$i != null) {
            bytesList$i = [];''';
        } else {
          code += 'final bytesList$i = <Uint8List$elNOp>[];';
        }
        code += 'for (var str in value$i) {';
        if (property.elementNullable) {
          code += 'if (str != null) {';
        }
        code += '''
          final bytes = BinaryWriter.utf8Encoder.convert(str);
          bytesList$i.add(bytes);
          dynamicSize += bytes.length;''';
        if (property.elementNullable) {
          code += '''
          } else {
            bytesList$i.add(null);
          }''';
        }
        if (property.nullable) {
          code += '}';
        }
        code += '''
        }
        final $accessor = bytesList$i;''';
        break;
      case IsarType.bytes:
      case IsarType.boolList:
      case IsarType.intList:
      case IsarType.floatList:
      case IsarType.longList:
      case IsarType.doubleList:
      case IsarType.dateTimeList:
        code +=
            'dynamicSize += (value$i$nOp.length $nLen) * ${property.isarType.elementSize};';
        break;
      default:
        break;
    }
    if (property.isarType != IsarType.string &&
        property.isarType != IsarType.stringList) {
      code += 'final $accessor = value$i;';
    }
  }
  code += '''
    final size = dynamicSize + $staticSize;
    ''';

  return code;
}

String _generateSerialize(ObjectInfo object) {
  var code = '''
  @override  
  int serialize(IsarCollection<${object.dartName}> collection, RawObject rawObj, ${object.dartName} object, List<int> offsets, [int? existingBufferSize]) {
    rawObj.id = object.${object.idProperty.dartName} ${object.idProperty.nullable ? '?? Isar.minId' : ''};
    ${_generatePrepareSerialize(object)}
    late int bufferSize;
    if (existingBufferSize != null) {
      if (existingBufferSize < size) {
        malloc.free(rawObj.buffer);
        rawObj.buffer = malloc(size);
        bufferSize = size;
      } else {
        bufferSize = existingBufferSize;
      }
    } else {
      rawObj.buffer = malloc(size);
      bufferSize = size;
    }
    rawObj.buffer_length = size;
    final buffer = rawObj.buffer.asTypedList(size);
    final writer = BinaryWriter(buffer, ${object.staticSize});
  ''';
  for (var i = 0; i < object.objectProperties.length; i++) {
    final property = object.objectProperties[i];
    final accessor = '_${property.isarName}';
    switch (property.isarType) {
      case IsarType.bool:
        code += 'writer.writeBool(offsets[$i], $accessor);';
        break;
      case IsarType.int:
        code += 'writer.writeInt(offsets[$i], $accessor);';
        break;
      case IsarType.float:
        code += 'writer.writeFloat(offsets[$i], $accessor);';
        break;
      case IsarType.long:
        code += 'writer.writeLong(offsets[$i], $accessor);';
        break;
      case IsarType.double:
        code += 'writer.writeDouble(offsets[$i], $accessor);';
        break;
      case IsarType.dateTime:
        code += 'writer.writeDateTime(offsets[$i], $accessor);';
        break;
      case IsarType.string:
        code += 'writer.writeBytes(offsets[$i], $accessor);';
        break;
      case IsarType.bytes:
        code += 'writer.writeBytes(offsets[$i], $accessor);';
        break;
      case IsarType.boolList:
        code += 'writer.writeBoolList(offsets[$i], $accessor);';
        break;
      case IsarType.stringList:
        code += 'writer.writeStringList(offsets[$i], $accessor);';
        break;
      case IsarType.intList:
        code += 'writer.writeIntList(offsets[$i], $accessor);';
        break;
      case IsarType.longList:
        code += 'writer.writeLongList(offsets[$i], $accessor);';
        break;
      case IsarType.floatList:
        code += 'writer.writeFloatList(offsets[$i], $accessor);';
        break;
      case IsarType.doubleList:
        code += 'writer.writeDoubleList(offsets[$i], $accessor);';
        break;
      case IsarType.dateTimeList:
        code += 'writer.writeDateTimeList(offsets[$i], $accessor);';
        break;
    }
  }

  code += _generateAttachLinks(object, 'collection', false);

  return '''
    $code
    return bufferSize;
  }''';
}

String _generateDeserialize(ObjectInfo object) {
  var code = '''
  @override
  ${object.dartName} deserialize(IsarCollection<${object.dartName}> collection, int id, BinaryReader reader, List<int> offsets) {
    final object = ${object.dartName}(''';
  final propertiesByMode = object.properties.groupBy((p) => p.deserialize);
  final positional = propertiesByMode[PropertyDeser.positionalParam] ?? [];
  final sortedPositional = positional.sortedBy((p) => p.constructorPosition!);
  for (var p in sortedPositional) {
    final index = object.objectProperties.indexOf(p);
    final deser = _deserializeProperty(object, p, 'offsets[$index]');
    code += '$deser,';
  }

  final named = propertiesByMode[PropertyDeser.namedParam] ?? [];
  for (var p in named) {
    final index = object.objectProperties.indexOf(p);
    final deser = _deserializeProperty(object, p, 'offsets[$index]');
    code += '${p.dartName}: $deser,';
  }

  code += ');';

  final assign = propertiesByMode[PropertyDeser.assign] ?? [];
  for (var p in assign) {
    final index = object.objectProperties.indexOf(p);
    final deser = _deserializeProperty(object, p, 'offsets[$index]');
    code += 'object.${p.dartName} = $deser;';
  }

  code += _generateAttachLinks(object, 'collection', true);

  return '''
      $code
      return object;
    }
    ''';
}

String _generateDeserializeProperty(ObjectInfo object) {
  var code = '''
  @override
  P deserializeProperty<P>(int id, BinaryReader reader, int propertyIndex, int offset) {
    switch (propertyIndex) {
      case -1:
        return id as P;''';

  for (var i = 0; i < object.objectProperties.length; i++) {
    final property = object.objectProperties[i];
    final deser = _deserializeProperty(object, property, 'offset');
    code += 'case $i: return ($deser) as P;';
  }

  return '''
      $code
      default:
        throw 'Illegal propertyIndex';
      }
    }
    ''';
}

String _deserializeProperty(
    ObjectInfo object, ObjectProperty property, String propertyOffset) {
  final orNull = property.nullable ? 'OrNull' : '';
  final orNullList = property.nullable ? '' : '?? []';
  final orElNull = property.elementNullable ? 'OrNull' : '';

  if (property.isId) {
    return 'id';
  }

  String? deser;
  switch (property.isarType) {
    case IsarType.bool:
      return 'reader.readBool$orNull($propertyOffset)';
    case IsarType.int:
      deser = 'reader.readInt$orNull($propertyOffset)';
      break;
    case IsarType.float:
      deser = 'reader.readFloat$orNull($propertyOffset)';
      break;
    case IsarType.long:
      deser = 'reader.readLong$orNull($propertyOffset)';
      break;
    case IsarType.double:
      deser = 'reader.readDouble$orNull($propertyOffset)';
      break;
    case IsarType.dateTime:
      deser = 'reader.readDateTime$orNull($propertyOffset)';
      break;
    case IsarType.string:
      deser = 'reader.readString$orNull($propertyOffset)';
      break;
    case IsarType.bytes:
      deser = 'reader.readBytes$orNull($propertyOffset)';
      break;
    case IsarType.boolList:
      deser = 'reader.readBool${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.stringList:
      deser = 'reader.readString${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.intList:
      deser = 'reader.readInt${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.floatList:
      deser = 'reader.readFloat${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.longList:
      deser = 'reader.readLong${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.doubleList:
      deser = 'reader.readDouble${orElNull}List($propertyOffset) $orNullList';
      break;
    case IsarType.dateTimeList:
      deser = 'reader.readDateTime${orElNull}List($propertyOffset) $orNullList';
      break;
  }

  return property.fromIsar(deser, object);
}

String _generateAttachLinks(
    ObjectInfo object, String collection, bool assignNew) {
  var code = '';
  for (var link in object.links) {
    String targetColGetter;
    if (link.targetCollectionDartName != object.dartName) {
      targetColGetter =
          '$collection.isar.${link.targetCollectionDartName.decapitalize()}s';
    } else {
      targetColGetter = collection;
    }
    if (assignNew) {
      code += 'object.${link.dartName} = IsarLink${link.links ? 's' : ''}().';
    } else {
      code += '''if (!object.${link.dartName}.attached) {
        object.${link.dartName}''';
    }
    code += '''.attach(
      $collection,
      $targetColGetter,
      object,
      "${link.dartName}",
      ${link.backlink},
    );
    ''';
    if (!assignNew) {
      code += '}';
    }
  }
  return code;
}
