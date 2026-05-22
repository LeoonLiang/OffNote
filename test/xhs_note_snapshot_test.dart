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
              "time":1754035806000,
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
    expect(snapshot.content, contains('\n')); // newlines must be preserved
    expect(
      snapshot.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1754035806000),
    );
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

  test('preserves line breaks from rendered note-content with br tags', () {
    const html = '''
    <html>
      <head><title>测试标题 - 小红书</title></head>
      <body>
        <div class="image-gallery-container">
          <div class="onix-carousel-item"><img src="http://sns-webpic-qc.xhscdn.com/a.jpg"></div>
        </div>
        <div class="note-content">第一段内容<br>第二段内容<br><br>第三段内容</div>
      </body>
    </html>
    ''';

    final snapshot = parseXhsNoteSnapshot(
      html: html,
      sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.content, '第一段内容\n第二段内容\n\n第三段内容');
  });

  test(
    'uses INITIAL_STATE desc (with newlines) even when carousel images are rendered',
    () {
      // Real-world case: page has rendered carousel but INITIAL_STATE JSON
      // (which contains undefined values) is the only source of content with newlines.
      const html = r'''
    <html>
      <head>
        <meta name="description" content="第一行 第二行 第三行">
      </head>
      <body>
        <div class="image-gallery-container">
          <div class="onix-carousel-item"><img src="http://sns-webpic-qc.xhscdn.com/a.jpg"></div>
        </div>
        <script>
          window.__INITIAL_STATE__={
            "note":{"noteDetailMap":{"abc":{"note":{
              "title":"标题",
              "desc":"第一行\n第二行\n第三行",
              "user":{"nickName":"用户"},
              "imageList":[{"url":"http:\\/\\/sns-webpic-qc.xhscdn.com\\/a.jpg"}],
              "jsAssetsList":undefined
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
      // Must use JSON desc, not the meta description (which has spaces instead of newlines)
      expect(snapshot!.content, '第一行\n第二行\n第三行');
    },
  );

  test('extracts video stream and poster from video note initial state', () {
    const html = r'''
    <html>
      <head><title>视频兜底标题 - 小红书</title></head>
      <body>
        <img id="video_note_poster" src="http://sns-webpic-qc.xhscdn.com/poster.jpg">
        <script>
          window.__INITIAL_STATE__={
            "note":{"noteDetailMap":{"abc":{"note":{
              "title":"外骨骼徒步",
              "desc":"走进雪山\n#外骨骼[话题]#",
              "user":{"nickname":"阿呸Ah bah","image":"https:\/\/sns-avatar-qc.xhscdn.com\/avatar\/demo.jpg"},
              "video":{"media":{"stream":{
                "h265":[{"masterUrl":"http:\/\/sns-video-v6.xhscdn.com\/stream\/h265.mp4","size":7844646,"format":"mp4"}],
                "h264":[
                  {"masterUrl":"http:\/\/sns-video-v6.xhscdn.com\/stream\/small.mp4","size":100,"format":"mp4"},
                  {"masterUrl":"http:\/\/sns-video-v6.xhscdn.com\/stream\/large.mp4?sign=abc","size":10908912,"format":"mp4"}
                ]
              }}}
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
    expect(snapshot!.title, '外骨骼徒步');
    expect(snapshot.content, '走进雪山\n#外骨骼[话题]#');
    expect(snapshot.authorName, '阿呸Ah bah');
    expect(snapshot.imageUrls, isEmpty);
    expect(
      snapshot.videoUrl,
      'https://sns-video-v6.xhscdn.com/stream/large.mp4?sign=abc',
    );
    expect(snapshot.posterUrl, 'https://sns-webpic-qc.xhscdn.com/poster.jpg');
  });

  test('extracts publish time from ld json when rendered carousel is used', () {
    const html = '''
    <html>
      <head>
        <title>格木村，让我来帮你宣传好了！ - 小红书</title>
        <meta name="description" content="正文内容">
        <script type="application/ld+json">{
          "datePublished": "1754035806000:00",
          "author": {"name": "蓝蓝"}
        }</script>
      </head>
      <body>
        <div class="image-gallery-container">
          <div class="onix-carousel-item"><img src="http://sns-webpic-qc.xhscdn.com/a.jpg"></div>
        </div>
      </body>
    </html>
    ''';

    final snapshot = parseXhsNoteSnapshot(
      html: html,
      sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
    );

    expect(snapshot, isNotNull);
    expect(
      snapshot!.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1754035806000),
    );
  });
}
