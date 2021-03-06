import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share/share.dart';
import 'package:tudo_client/list_manager/list_provider.dart';

void shareToDoList(BuildContext context, ToDoList list) {
  showModalBottomSheet<String>(
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    isScrollControlled: true,
    context: context,
    builder: (context) => _ShareListForm(list: list),
  );
}

class _ShareListForm extends StatelessWidget {
  final ToDoList list;

  String get shareUrl => 'https://tudo.cachapa.net/${list.id}';

  const _ShareListForm({Key? key, required this.list}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            list.name,
            style: Theme.of(context)
                .textTheme
                .headline6!
                .copyWith(color: list.color),
          ),
          SizedBox(height: 20),
          QrImage(
            data: shareUrl,
            version: QrVersions.auto,
            size: 250.0,
            backgroundColor: ThemeData.light().canvasColor,
          ),
          SizedBox(height: 20),
          ButtonBar(
            mainAxisSize: MainAxisSize.max,
            alignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(list.color)),
                icon: Icon(Icons.copy),
                label: Text('Copy Link'.toUpperCase()),
                onPressed: () {
                  FlutterClipboard.copy(shareUrl);
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: 16),
              TextButton.icon(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(list.color)),
                icon: Icon(Icons.share),
                label: Text('Share'.toUpperCase()),
                onPressed: () {
                  Share.share('Tap to open "${list.name}" in your device:\n'
                      '$shareUrl');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
