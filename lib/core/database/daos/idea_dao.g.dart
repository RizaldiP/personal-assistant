// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'idea_dao.dart';

// ignore_for_file: type=lint
mixin _$IdeaDaoMixin on DatabaseAccessor<AppDatabase> {
  $IdeasTable get ideas => attachedDatabase.ideas;
  IdeaDaoManager get managers => IdeaDaoManager(this);
}

class IdeaDaoManager {
  final _$IdeaDaoMixin _db;
  IdeaDaoManager(this._db);
  $$IdeasTableTableManager get ideas =>
      $$IdeasTableTableManager(_db.attachedDatabase, _db.ideas);
}
