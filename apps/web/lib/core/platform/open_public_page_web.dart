import 'package:web/web.dart' as web;

void openPublicPage(String path, {bool sameWindow = false}) {
  final link = web.HTMLAnchorElement()
    ..href = path
    ..target = sameWindow ? '_self' : '_blank'
    ..rel = 'noopener noreferrer';
  web.document.body!.append(link);
  link.click();
  link.remove();
}
