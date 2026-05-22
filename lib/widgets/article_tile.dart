part of '../main.dart';

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    required this.selected,
    required this.selectionMode,
    this.onLongPress,
    this.onDelete,
  });

  final SavedArticle article;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: EdgeInsets.zero,
      radius: BorderRadius.circular(8),
      border: ShadBorder.all(
        color: selected ? _accent : theme.colorScheme.border,
        width: selected ? 1.5 : 1,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? _accent : Colors.black26,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _ArticleMediaPreview(article: article),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.content,
                      maxLines: article.remark.isEmpty ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    if (article.remark.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: _accent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              article.remark,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MediaTypeBadge(mediaType: article.mediaType),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel(article.publishedAt),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                ShadIconButton.ghost(
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  foregroundColor: Colors.black45,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleMediaPreview extends StatelessWidget {
  const _ArticleMediaPreview({required this.article});

  final SavedArticle article;

  @override
  Widget build(BuildContext context) {
    final paths = article.imagePaths.isNotEmpty
        ? article.imagePaths
        : [if (article.coverPath != null) article.coverPath!];
    final isVideo = article.mediaType == ArticleMediaType.video;
    if (paths.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 108,
          height: 108,
          child: ColoredBox(
            color: _accentSoft,
            child: Icon(
              isVideo
                  ? Icons.play_circle_outline_rounded
                  : Icons.article_outlined,
              color: _accent,
            ),
          ),
        ),
      );
    }

    if (isVideo || paths.length == 1) {
      return _PreviewImage(path: paths.first, isVideo: isVideo);
    }

    return SizedBox(
      width: 108,
      height: 108,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: paths.take(9).length,
        itemBuilder: (context, index) =>
            _PreviewImage(path: paths[index], radius: 4, isVideo: false),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({
    required this.path,
    required this.isVideo,
    this.radius = 8,
  });

  final String path;
  final bool isVideo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: 108,
        height: 108,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: _accentSoft,
                child: Icon(Icons.broken_image_outlined, color: _accent),
              ),
            ),
            if (isVideo)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.mediaType});

  final ArticleMediaType mediaType;

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == ArticleMediaType.video;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isVideo ? const Color(0xffffeff2) : _accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_arrow_rounded : Icons.image_outlined,
            size: 12,
            color: isVideo ? const Color(0xffff2442) : _accent,
          ),
          const SizedBox(width: 3),
          Text(
            isVideo ? '视频' : '图文',
            style: TextStyle(
              color: isVideo ? const Color(0xffff2442) : _accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
