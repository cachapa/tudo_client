import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';
import 'package:provider/provider.dart';
import 'package:tudo_client/common/drag_handler.dart';
import 'package:tudo_client/common/edit_list.dart';
import 'package:tudo_client/common/offline_indicator.dart';
import 'package:tudo_client/common/progress.dart';
import 'package:tudo_client/extensions.dart';
import 'package:tudo_client/list_manager/list_provider.dart';
import 'package:tudo_client/to_to_list/to_do_list_page.dart';

final _controller = ScrollController();

class ListManagerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('bot: ${context.padding.bottom}');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: context.theme.brightness.invert,
      ),
      child: Scaffold(
        body: Consumer<ListProvider>(
          builder: (_, listManager, __) =>
              ImplicitlyAnimatedReorderableList<ToDoList>(
            controller: _controller,
            padding: EdgeInsets.only(bottom: context.padding.bottom),
            items: listManager.lists,
            shrinkWrap: true,
            areItemsTheSame: (oldItem, newItem) => oldItem?.id == newItem?.id,
            onReorderFinished: (_, from, to, __) => listManager.swap(from!, to),
            header: Logo(),
            itemBuilder: (_, itemAnimation, item, __) => Reorderable(
              key: ValueKey(item.id),
              builder: (_, __, ___) => SizeFadeTransition(
                sizeFraction: 0.7,
                curve: Curves.easeInOut,
                animation: itemAnimation,
                child: _ListItem(list: item),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.transparent,
          onPressed: () => _createList(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/images/icon_bg.png'),
              Text(
                't',
                style: TextStyle(
                  fontFamily: 'WaitingfortheSunrise',
                  fontSize: 50,
                  height: 1.3,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: OfflineIndicator(),
      ),
    );
  }

  Future<void> _createList(BuildContext context) async {
    final result = await editToDoList(context);
    if (result ?? false) {
      // Scroll to the bottom of the list
      Future.delayed(
        Duration(milliseconds: 400),
        () => _controller.animateTo(
          _controller.position.maxScrollExtent + 200,
          duration: Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
        ),
      );
    }
  }
}

class Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Text(
                'tudo',
                style: TextStyle(
                  fontFamily: 'WaitingfortheSunrise',
                  fontSize: 100,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.all(20),
              icon: Icon(Icons.qr_code_scanner),
              tooltip: 'Import using QR code',
              onPressed: () => _launchQrScanner(context),
            ),
          ],
        ),
      );

  Future<void> _launchQrScanner(BuildContext context) async {
    final code = await FlutterBarcodeScanner.scanBarcode(
      '#00000000',
      'CLOSE',
      false,
      ScanMode.QR,
    );
    if (code == '-1') return;
    print('Read QR: $code');
    await context.read<ListProvider>().import(code);
  }
}

class _ListItem extends StatelessWidget {
  final ToDoList list;

  _ListItem({Key? key, required this.list}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Progress(list: list),
      title: Text(
        list.name,
        style: context.theme.textTheme.headline6,
      ),
      trailing: DragHandle(),
      onTap: () => _openList(context),
      onLongPress: () => _editList(context),
    );
  }

  void _openList(BuildContext context) async {
    final action = await context.push(() => ToDoListPage(id: list.id));
    if (action != null && action == ListAction.delete) {
      Future.delayed(
        // Wait for pop animation to complete
        Duration(milliseconds: 310),
        () => _deleteList(context),
      );
    }
  }

  void _editList(BuildContext context) =>
      editToDoList(context, list, () => _deleteList(context));

  void _deleteList(BuildContext context) {
    final listManager = context.read<ListProvider>();
    final index = listManager.remove(list.id);
    context.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${list.name} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => listManager.import(list.id, index),
        ),
      ),
    );
  }
}
