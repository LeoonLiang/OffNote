import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/xhs_note_snapshot.dart';

void main() {
  test('extracts note images, author, title and body from initial state', () {
    const html = '''
    <html>
      <head><title>兜底标题</title></head>
      <body>
        <script>
          window.__INITIAL_STATE__={
            "note":{"noteDetailMap":{"688c":{"note":{
              "title":"格木村，让我来帮你宣传好了！",
              "desc":"徒步格聂扎营格木村\\n#这里是格聂[话题]#",
              "user":{
                "nickName":"蓝蓝",
                "avatar":"https:\\/\\/sns-avatar-qc.xhscdn.com\\/avatar\\/demo.jpg"
              },
              "imageList":[
                {"url":"http:\\/\\/sns-webpic-qc.xhscdn.com\\/a.jpg"},
                {"infoList":[{"imageScene":"H5_DTL","url":"http:\\/\\/sns-webpic-qc.xhscdn.com\\/b.jpg"}]}
              ]
            }}}}
          }
        </script>
      </body>
    </html>
    ''';

    final snapshot = parseXhsNoteSnapshot(
      html: html,
      sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.title, '格木村，让我来帮你宣传好了！');
    expect(snapshot.authorName, '蓝蓝');
    expect(
      snapshot.authorAvatarUrl,
      'https://sns-avatar-qc.xhscdn.com/avatar/demo.jpg',
    );
    expect(snapshot.content, contains('徒步格聂扎营格木村'));
    expect(snapshot.imageUrls, [
      'https://sns-webpic-qc.xhscdn.com/a.jpg',
      'https://sns-webpic-qc.xhscdn.com/b.jpg',
    ]);
  });

  test('prefers rendered carousel images and excludes avatars', () {
    const html = '''
    <html>
      <head>
        <title>格木村，让我来帮你宣传好了！ - 小红书</title>
        <meta name="description" content="正文内容">
        <script type="application/ld+json">{
          "author": {
            "name": "蓝蓝",
            "image": "https://sns-avatar-qc.xhscdn.com/avatar/demo.jpg"
          }
        }</script>
      </head>
      <body>
        <div class="image-gallery-container">
          <div class="onix-carousel-item"><img src="http://sns-webpic-qc.xhscdn.com/a.jpg"></div>
          <div class="onix-carousel-item"><img src="http://sns-webpic-qc.xhscdn.com/b.jpg"></div>
        </div>
        <img class="avatar" src="https://sns-avatar-qc.xhscdn.com/avatar/other.jpg">
      </body>
    </html>
    ''';

    final snapshot = parseXhsNoteSnapshot(
      html: html,
      sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.authorName, '蓝蓝');
    expect(
      snapshot.authorAvatarUrl,
      'https://sns-avatar-qc.xhscdn.com/avatar/demo.jpg',
    );
    expect(snapshot.imageUrls, [
      'https://sns-webpic-qc.xhscdn.com/a.jpg',
      'https://sns-webpic-qc.xhscdn.com/b.jpg',
    ]);
  });
}
