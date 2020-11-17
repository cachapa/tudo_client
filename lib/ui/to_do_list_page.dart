import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';
import 'package:provider/provider.dart';
import 'package:tudo_client/data/list_manager.dart';
import 'package:tudo_client/ui/share_list.dart';
import 'package:tudo_client/ui/text_input_dialog.dart';

import 'custom_handle.dart';
import 'edit_list.dart';
import 'empty_page.dart';
import 'icon_text.dart';

const titleBarHeight = 60.0;
const inputBarHeight = 60.0;
const blurSigma = 14.0;

class ToDoListPage extends StatelessWidget {
  final String id;

  ToDoListPage({Key key, this.id}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<ListManager, ToDoList>(
      selector: (_, listManager) => listManager.get(id),
      builder: (_, list, __) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: list.color),
          primaryColor: list.color,
          accentColor: list.color,
          primaryTextTheme: TextTheme(headline6: TextStyle(color: list.color)),
          primaryIconTheme: IconThemeData(color: list.color),
          iconTheme: IconThemeData(color: list.color),
          toggleableActiveColor: list.color,
          textSelectionHandleColor: list.color,
          textSelectionColor: list.color,
          cursorColor: list.color,
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: TitleBar(
            list: list,
            actions: [
              PopupMenuButton<Function>(
                icon: Icon(Icons.settings),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: IconText(Icons.share, 'Share'),
                    value: () => shareToDoList(context, list),
                  ),
                  PopupMenuItem(
                    child: IconText(Icons.edit, 'Edit'),
                    value: () => editToDoList(context, list),
                  ),
                ],
                onSelected: (value) => value(),
              ),
            ],
          ),
          body: list.toDos.isEmpty
              ? EmptyPage(text: 'Create a new to-do item below')
              : ToDoListView(toDoList: list),
          floatingActionButton: InputBar(
            onSubmitted: (value) => list.add(value),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ),
      ),
    );
  }
}

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final ToDoList list;
  final List<Widget> actions;

  const TitleBar({Key key, this.list, this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          centerTitle: true,
          backgroundColor: primaryColor.withAlpha(20),
          elevation: 0,
          title: Text(
            list.name,
            overflow: TextOverflow.fade,
          ),
          actions: actions,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class InputBar extends StatelessWidget {
  final Function(String value) onSubmitted;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  InputBar({Key key, this.onSubmitted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final insetBottom = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: EdgeInsets.only(bottom: insetBottom),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: primaryColor,
              style: Theme.of(context)
                  .textTheme
                  .subtitle1
                  .copyWith(color: primaryColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: primaryColor.withAlpha(30),
                contentPadding: EdgeInsets.all(20),
                hintText: 'Add Item',
                border: InputBorder.none,
                suffixIcon: IconButton(
                  padding: EdgeInsets.only(right: 10),
                  icon: Icon(Icons.add),
                  onPressed: () => _onSubmitted(_controller.text),
                ),
              ),
              maxLines: 1,
              onSubmitted: (text) => _onSubmitted(text),
            ),
          ),
        ),
      ),
    );
  }

  void _onSubmitted(String text) {
    onSubmitted(text);
    _controller.clear();
    _focusNode.requestFocus();
  }
}

class ToDoListView extends StatelessWidget {
  final ToDoList toDoList;

  const ToDoListView({Key key, this.toDoList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final insetTop = MediaQuery.of(context).padding.top;
    final insetBottom =
        MediaQuery.of(context).viewPadding.bottom + inputBarHeight + 20;

    final uncheckedItems =
        toDoList.toDos.where((item) => !item.checked).toList();
    final checkedItems = toDoList.toDos.where((item) => item.checked).toList();

    return ListView(
      padding: EdgeInsets.only(top: insetTop, bottom: insetBottom),
      children: [
        ImplicitlyAnimatedReorderableList<ToDo>(
          items: uncheckedItems,
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
          reorderDuration: Duration(milliseconds: 200),
          areItemsTheSame: (oldItem, newItem) => oldItem == newItem,
          onReorderFinished: (_, from, to, __) => toDoList.swap(from, to),
          itemBuilder: (_, itemAnimation, item, __) => Reorderable(
            key: ValueKey(item.id),
            builder: (context, animation, inDrag) => SizeFadeTransition(
              sizeFraction: 0.7,
              curve: Curves.easeInOut,
              animation: itemAnimation,
              child: _ListTile(
                item: item,
                onToggle: () => _toggle(item),
                onEdit: () => _editItem(context, item),
                onDelete: () => _deleteItem(context, item),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          duration: Duration(milliseconds: 300),
          opacity: checkedItems.isEmpty ? 0 : 1,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              // color: toDoList.color.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(
                  color: toDoList.color.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
            padding: EdgeInsets.only(left: 16, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Completed',
                    style: Theme.of(context)
                        .textTheme
                        .subtitle2
                        .copyWith(color: toDoList.color),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _clearCompleted(context, toDoList),
                ),
              ],
            ),
          ),
        ),
        ImplicitlyAnimatedList(
          items: checkedItems,
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
          areItemsTheSame: (oldItem, newItem) => oldItem == newItem,
          itemBuilder: (context, itemAnimation, item, i) => SizeFadeTransition(
            sizeFraction: 0.7,
            curve: Curves.easeInOut,
            animation: itemAnimation,
            child: _ListTile(
              item: item,
              onToggle: () => _toggle(item),
              onEdit: () => _editItem(context, item),
              onDelete: () => _deleteItem(context, item),
            ),
          ),
        ),
      ],
    );
  }

  _toggle(ToDo toDo) => toDoList.set(toDo.id, checked: !toDo.checked);

  _editItem(BuildContext context, ToDo toDo) {
    showDialog<String>(
      context: context,
      child: TextInputDialog(
        value: toDo.name,
        onSet: (value) => toDoList.set(toDo.id, name: value),
      ),
    );
  }

  _deleteItem(BuildContext context, ToDo toDo) {
    final index = toDoList.remove(toDo.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${toDo.name} deleted"),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => toDoList.set(toDo.id,
              name: toDo.name, checked: toDo.checked, index: index),
        ),
      ),
    );
  }

  _clearCompleted(BuildContext context, ToDoList list) {
    var checked = list.toDos.where((item) => item.checked).toList();
    if (checked.isEmpty) return;

    var indexes = checked.map((e) => list.remove(e.id)).toList();

    // Insert in reverse order when undoing so the old indexes match
    checked = checked.reversed.toList();
    indexes = indexes.reversed.toList();
    final count = checked.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Cleared $count completed ${count == 1 ? 'item' : 'items'}'),
        action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              for (var i = 0; i < checked.length; i++) {
                final item = checked[i];
                list.set(item.id,
                    name: item.name, checked: item.checked, index: indexes[i]);
              }
            }),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final ToDo item;
  final Function() onToggle;
  final Function() onEdit;
  final Function() onDelete;

  const _ListTile(
      {Key key, this.item, this.onToggle, this.onEdit, this.onDelete})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: item.checked
          ? Padding(
              padding: EdgeInsets.only(left: 16),
              child: Checkbox(
                onChanged: (_) => onToggle(),
                value: item.checked,
              ),
            )
          : CustomHandle(
              child: Checkbox(
                onChanged: (_) => onToggle(),
                value: item.checked,
              ),
            ),
      title: Text(item.name),
      onTap: () => onToggle(),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem<Function>(
            child: IconText(Icons.edit, 'Edit'),
            value: () => onEdit(),
          ),
          PopupMenuItem<Function>(
            child: IconText(Icons.delete, 'Delete', color: Colors.red),
            value: () => onDelete(),
          ),
        ],
        onSelected: (value) => value(),
      ),
    );
  }
}
