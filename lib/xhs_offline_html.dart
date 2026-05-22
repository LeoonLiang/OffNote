String buildXhsOfflineHtml({
  required String title,
  required String content,
  required List<String> localImageUris,
  String? localVideoUri,
  String? localPosterUri,
  int failedImageCount = 0,
  bool videoDownloadFailed = false,
  String? authorName,
  String? authorAvatarUri,
}) {
  final hasVideo = localVideoUri != null && localVideoUri.isNotEmpty;
  final mediaWarnings = [
    if (failedImageCount > 0) '$failedImageCount 张图片保存失败',
    if (videoDownloadFailed) '视频保存失败',
  ];
  final warningHtml = mediaWarnings.isEmpty
      ? ''
      : '<div class="media-warning"><strong>媒体未完整保存</strong><span>${_escapeHtml(mediaWarnings.join('，'))}</span></div>';
  final slides = localImageUris.indexed
      .map(
        (entry) =>
            '<figure class="slide"><img src="${_escapeAttribute(entry.$2)}" loading="${entry.$1 == 0 ? 'eager' : 'lazy'}" decoding="async"></figure>',
      )
      .join();
  final indicatorDots = localImageUris.indexed
      .map(
        (entry) =>
            '<button class="dot${entry.$1 == 0 ? ' active' : ''}" type="button" aria-label="第 ${entry.$1 + 1} 张"></button>',
      )
      .join();
  final avatar = authorAvatarUri == null
      ? '<div class="avatar avatar-placeholder"></div>'
      : '<img class="avatar" src="${_escapeAttribute(authorAvatarUri)}" alt="">';
  final gallery = hasVideo
      ? '''
    <section class="gallery">
      <video class="video-player" controls playsinline preload="metadata"${localPosterUri == null ? '' : ' poster="${_escapeAttribute(localPosterUri)}"'}>
        <source src="${_escapeAttribute(localVideoUri)}" type="video/mp4">
      </video>
      $warningHtml
    </section>'''
      : localImageUris.isEmpty
      ? '''
    <section class="gallery gallery-empty">
      <div class="empty-media">
        <strong>媒体未完整保存</strong>
        <span>${mediaWarnings.isEmpty ? '没有可离线查看的图片或视频' : _escapeHtml(mediaWarnings.join('，'))}</span>
      </div>
    </section>'''
      : '''
    <section class="gallery">
      <div class="counter"><span id="current-slide">1</span> / ${localImageUris.length}</div>
      <section id="carousel" class="carousel" aria-label="图片轮播">$slides</section>
      <div id="dots" class="dots">$indicatorDots</div>
      $warningHtml
    </section>''';

  return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${_escapeHtml(title)}</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #191919;
      --muted: #6b6b6b;
      --line: #ececec;
      --paper: #fff;
      --bg: #f6f6f6;
      --accent: #ff2442;
    }
    * { box-sizing: border-box; }
    html, body { margin: 0; background: var(--bg); color: var(--ink); font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", Arial, sans-serif; }
    body { min-height: 100vh; }
    .page { max-width: 520px; margin: 0 auto; background: var(--paper); min-height: 100vh; }
    .gallery { position: relative; background: #0f0f0f; }
    .gallery-empty { min-height: 260px; display: flex; align-items: center; justify-content: center; padding: 24px; }
    .carousel { display: flex; overflow-x: auto; scroll-snap-type: x mandatory; overscroll-behavior-x: contain; background: #0f0f0f; }
    .carousel::-webkit-scrollbar { display: none; }
    .slide { flex: 0 0 100%; margin: 0; min-height: 320px; max-height: 72vh; scroll-snap-align: center; display: flex; align-items: center; justify-content: center; background: #111; }
    .slide img { width: 100%; height: 100%; object-fit: contain; display: block; }
    .video-player { width: 100%; max-height: 72vh; min-height: 320px; display: block; background: #111; object-fit: contain; }
    .counter { position: absolute; right: 12px; top: 12px; z-index: 2; padding: 4px 9px; border-radius: 999px; background: rgba(0,0,0,.48); color: #fff; font-size: 12px; font-weight: 700; }
    .dots { position: absolute; left: 0; right: 0; bottom: 10px; z-index: 2; display: flex; justify-content: center; gap: 5px; pointer-events: none; }
    .dot { width: 5px; height: 5px; padding: 0; border: 0; border-radius: 50%; background: rgba(255,255,255,.52); }
    .dot.active { width: 14px; border-radius: 999px; background: #fff; }
    .media-warning { position: absolute; left: 12px; right: 12px; bottom: 12px; z-index: 3; display: flex; gap: 6px; align-items: center; padding: 8px 10px; border-radius: 12px; color: #fff; background: rgba(0,0,0,.62); font-size: 12px; line-height: 1.35; }
    .media-warning strong { flex: 0 0 auto; }
    .empty-media { display: flex; flex-direction: column; align-items: center; gap: 8px; color: #fff; text-align: center; line-height: 1.45; }
    .empty-media strong { font-size: 16px; }
    .empty-media span { color: rgba(255,255,255,.74); font-size: 13px; }
    .meta { display: flex; align-items: center; gap: 10px; padding: 14px 16px 8px; }
    .avatar { width: 34px; height: 34px; border-radius: 50%; object-fit: cover; background: #eee; flex: 0 0 auto; }
    .avatar-placeholder { background: linear-gradient(135deg, #ffd7de, #f2f2f2); }
    .author { font-size: 14px; font-weight: 700; line-height: 1.2; }
    .source { margin-left: auto; color: var(--accent); font-size: 12px; font-weight: 700; }
    .content { padding: 6px 16px 28px; border-top: 1px solid var(--line); }
    h1 { margin: 12px 0 10px; font-size: 20px; line-height: 1.35; letter-spacing: 0; }
    .desc { margin: 0; white-space: pre-wrap; font-size: 15px; line-height: 1.75; letter-spacing: 0; color: #252525; }
  </style>
</head>
<body>
  <main class="page">
$gallery
    <section class="meta">
      $avatar
      <div class="author">${_escapeHtml(authorName ?? '小红书用户')}</div>
      <div class="source">小红书</div>
    </section>
    <article class="content">
      <h1>${_escapeHtml(title)}</h1>
      <p class="desc">${_escapeHtml(content)}</p>
    </article>
  </main>
  <script>
    (function () {
      var carousel = document.getElementById('carousel');
      var current = document.getElementById('current-slide');
      var dots = Array.prototype.slice.call(document.querySelectorAll('.dot'));
      if (!carousel || !current || !dots.length) return;
      function update() {
        var index = Math.round(carousel.scrollLeft / Math.max(1, carousel.clientWidth));
        index = Math.max(0, Math.min(dots.length - 1, index));
        current.textContent = String(index + 1);
        dots.forEach(function (dot, dotIndex) {
          dot.classList.toggle('active', dotIndex === index);
        });
      }
      carousel.addEventListener('scroll', function () {
        window.requestAnimationFrame(update);
      }, { passive: true });
      update();
    })();
  </script>
</body>
</html>
''';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _escapeAttribute(String value) => _escapeHtml(value);
