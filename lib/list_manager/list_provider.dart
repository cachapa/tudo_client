import 'package:crdt/crdt.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_crdt/hive_crdt.dart';
import 'package:tudo_client/extensions.dart';
import 'package:tudo_client/util/random_id.dart';

const listIdsKey = 'list_id_keys';

class ListProvider with ChangeNotifier {
  final String nodeId;
  final Box<List<String>> _box;
  final _toDoLists = <String, ToDoList>{};

  late final Future _initFuture;

  List<String> get listIds => _box.get(listIdsKey, defaultValue: [])!.toList();

  set _listIds(List<String> values) => _box.put(listIdsKey, values);

  List<ToDoList> get lists => listIds
      .map((e) => _toDoLists[e])
      .where((e) => e != null)
      .map((e) => e!)
      .toList();

  static Future<ListProvider> open(String nodeId) async {
    final box = await Hive.openBox<List<String>>('store');
    return ListProvider._(nodeId, box);
  }

  ListProvider._(this.nodeId, this._box) {
    _initFuture = _init();
  }

  Future<void> _init() async {
    // Sanity check: remove duplicate list ids
    final set = listIds.toSet();
    if (set.length != listIds.length) {
      print('WARNING: Detected duplicate list ids. Fixing…');
      _listIds = set.toList();
    }

    // Open all the to do lists
    await Future.wait(listIds
        .map((e) async => _toDoLists[e] = await ToDoList.import(this, e)));
    notify();
  }

  Future<void> create(String name, Color color) async {
    await _initFuture;

    final id = generateRandomId();
    _listIds = listIds..add(id);
    _toDoLists[id] = await ToDoList.open(this, id, name, color);
    notify();
  }

  Future<void> import(String id, [int? index]) async {
    await _initFuture;

    // Remove url section if present
    id = id.replaceFirst('https://tudo.cachapa.net/', '');

    if (listIds.contains(id)) {
      print('Import: already have $id');
      return;
    }

    print('Importing $id');
    _listIds =
        index == null ? (listIds..add(id)) : (listIds..insert(index, id));
    _toDoLists[id] = await ToDoList.import(this, id);
    notify();
  }

  ToDoList? get(String id) => _toDoLists[id];

  void swap(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final id = listIds[oldIndex];
    _listIds = listIds
      ..removeAt(oldIndex)
      ..insert(newIndex, id);
  }

  int remove(String id) {
    final index = listIds.indexOf(id);
    _listIds = listIds..remove(id);
    _toDoLists.remove(id);
    notify();
    return index;
  }

  void notify() => notifyListeners();
}

class ToDoList {
  static final nameKey = '__name__';
  static final colorKey = '__color__';
  static final orderKey = '__order__';

  final ListProvider _parent;
  final String id;
  final Crdt<String, dynamic> _toDoCrdt;

  String get name => _toDoCrdt.get(nameKey) ?? 'loading';

  Color get color => _toDoCrdt.get(colorKey) ?? Colors.blue;

  int get length => _toDoCrdt.values.whereType<ToDo>().length;

  int get uncompletedLength =>
      _toDoCrdt.values.whereType<ToDo>().where((e) => !e.checked).length;

  int get completedLength =>
      _toDoCrdt.values.whereType<ToDo>().where((e) => e.checked).length;

  bool get isEmpty => _toDoCrdt.isEmpty;

  List<ToDo> get toDos => _toDoCrdt.values.whereType<ToDo>().toList()
    ..sort((a, b) {
      var ia = _order.indexOf(a.id);
      ia = ia < 0 ? 1000000 : ia;
      var ib = _order.indexOf(b.id);
      ib = ib < 0 ? 1000000 : ib;
      return ia != ib ? ia.compareTo(ib) : a.name.compareTo(b.name);
    });

  List<String> get _order =>
      _toDoCrdt.get(orderKey)?.cast<String>().toList() ?? [];

  set _order(List<String> values) => _toDoCrdt.put(orderKey, values);

  Hlc get canonicalTime => _toDoCrdt.canonicalTime;

  set name(String value) {
    value = value.trim();
    if (value == name) return;
    _toDoCrdt.put(nameKey, value);
    _parent.notify();
  }

  set color(Color value) {
    if (value == color) return;
    _toDoCrdt.put(colorKey, value);
    _parent.notify();
  }

  ToDoList._internal(this._parent, this.id, this._toDoCrdt) {
    // Verify order integrity
    final toDos = _toDoCrdt.values.whereType<ToDo>().toList();
    if (_order.length != toDos.length) {
      _order = (toDos..sort((a, b) => a.name.compareTo(b.name)))
          .map((e) => e.id)
          .toList();
    }
  }

  static Future<ToDoList> open(
      ListProvider parent, String id, String? name, Color? color) async {
    late final crdt;
    try {
      crdt = await HiveCrdt.open<String, dynamic>(id, parent.nodeId);
    } catch (e) {
      print('$e\nResetting store');
      await Hive.deleteBoxFromDisk(id);
      crdt = await HiveCrdt.open<String, dynamic>(id, parent.nodeId);
    }
    if (name != null) crdt.put(nameKey, name.trim());
    if (color != null) crdt.put(colorKey, color);
    return ToDoList._internal(parent, id, crdt);
  }

  static Future<ToDoList> import(ListProvider parent, String id) =>
      open(parent, id, null, null);

  ToDo add(String name) => set(generateRandomId(), name: name, checked: false)!;

  ToDo? set(String id,
      {String? name, bool? checked, int? index, bool? isDeleted}) {
    if (name != null && name.trim().isEmpty) return null;

    if (!_order.contains(id)) {
      _order = _order..insert(index ?? _order.length, id);
    }

    final toDo = (_toDoCrdt.map[id] as ToDo?)?.copyWith(
            newName: name, newChecked: checked, newDeleted: isDeleted) ??
        ToDo(id, name!, checked!);

    _toDoCrdt.put(id, toDo);
    _parent.notify();

    return toDo;
  }

  void swap(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final id = _order[oldIndex];
    _order = _order
      ..removeAt(oldIndex)
      ..insert(newIndex, id);
    _parent.notify();
  }

  int remove(String id) {
    final index = _order.indexOf(id);
    _order = _order..remove(id);
    _toDoCrdt.delete(id);
    _parent.notify();
    return index;
  }

  String toJson(Hlc? lastSync) => _toDoCrdt.toJson(
      modifiedSince: lastSync,
      valueEncoder: (key, value) => value is Color ? value.hexValue : value);

  void mergeJson(String json) {
    final original = _toDoCrdt.recordMap();

    _toDoCrdt.mergeJson(
      json,
      valueDecoder: (key, value) {
        return value is Map<String, dynamic>
            ? ToDo.fromJson(value)
            : key == colorKey
                ? ColorExtensions.fromHex(value)
                : value;
      },
    );
    if (_toDoCrdt.recordMap().toString() != original.toString()) {
      _parent.notify();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ToDoList &&
      id == other.id &&
      name == other.name &&
      _toDoCrdt.recordMap() == other._toDoCrdt.recordMap();

  @override
  int get hashCode => id.hashCode & name.hashCode & _toDoCrdt.hashCode;

  @override
  String toString() => '$name [$length]';
}

class ToDo {
  final String id;
  final String name;
  final bool checked;

  // Transient marker while item is deleted
  final bool isDeleted;

  ToDo(this.id, String name, this.checked, [this.isDeleted = false])
      : name = name.trim();

  ToDo copyWith({String? newName, bool? newChecked, bool? newDeleted}) =>
      ToDo(id, newName ?? name, newChecked ?? checked, newDeleted ?? isDeleted);

  factory ToDo.fromJson(Map<String, dynamic> map) =>
      ToDo(map['id'], map['name'], map['checked'], false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'checked': checked,
      };

  @override
  bool operator ==(Object other) => other is ToDo && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => toJson().toString();
}
