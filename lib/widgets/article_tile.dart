part of '../main.dart';

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    this.onDelete,
  });

  final SavedArticle article;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final coverPath = article.coverPath;
    final theme = ShadTheme.of(context);
    final isVideo = article.mediaType == ArticleMediaType.video;
    return ShadCard(
      padding: EdgeInsets.zero,
      radius: BorderRadius.circular(18),
      border: ShadBorder.all(color: theme.colorScheme.border),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 86,
                  height: 76,
                  child: coverPath == null
                      ? ColoredBox(
                          color: _accentSoft,
                          child: Icon(
                            isVideo
                                ? Icons.play_circle_outline_rounded
                                : Icons.article_outlined,
                            color: _accent,
                          ),
                        )
                      : Image.file(File(coverPath), fit: BoxFit.cover),
                ),
              ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MediaTypeBadge(mediaType: article.mediaType),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel(article.createdAt),
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
