import 'dart:convert';
import 'package:web/web.dart' as web;

void downloadCsv(String csv) {
  final uri =
      'data:text/csv;charset=utf-8;base64,${base64Encode(utf8.encode(csv))}';
  final link = web.HTMLAnchorElement()
    ..href = uri
    ..download = 'paylog-ledger.csv';
  web.document.body!.append(link);
  link.click();
  link.remove();
}

void downloadConnection(String contents) {
  final link = web.HTMLAnchorElement()
    ..href =
        'data:application/json;base64,${base64Encode(utf8.encode(contents))}'
    ..download = 'paylog-connection.json';
  web.document.body!.append(link);
  link.click();
  link.remove();
}
