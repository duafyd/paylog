import 'package:web/web.dart' as web;

void openPublicPage(String path) {
  final link = web.HTMLAnchorElement()
    ..href = path
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  web.document.body!.append(link);
  link.click();
  link.remove();
}
