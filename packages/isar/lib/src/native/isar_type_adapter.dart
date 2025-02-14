import 'package:isar/isar.dart';

abstract class IsarTypeAdapter<T> {
  const IsarTypeAdapter();

  int serialize(IsarCollection<T> collection, RawObject rawObj, T object,
      List<int> offsets,
      [int? existingBufferSize]);

  T deserialize(IsarCollection<T> collection, int id, BinaryReader reader,
      List<int> offsets);

  P deserializeProperty<P>(
      int id, BinaryReader reader, int propertyIndex, int offset);
}
