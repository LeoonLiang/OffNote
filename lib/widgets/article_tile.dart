part of '../main.dart';

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    required this.selected,
    required this.selectionMode,
    this.categoryLabel,
    this.tags = const [],
    this.onLongPress,
    this.onDelete,
  });

  final SavedArticle article;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool selected;
  final bool selectionMode;
  final String? categoryLabel;
  final List<SavedTag> tags;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (article.isStarred) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: Color(0xffffb300),
                          ),
                        ],
                      ],
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
                        if (categoryLabel != null) ...[
                          Flexible(
                            child: _CategoryBadge(label: categoryLabel!),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ..._visibleTagBadges(tags),
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

List<Widget> _visibleTagBadges(List<SavedTag> tags) {
  if (tags.isEmpty) {
    return const [];
  }
  final visible = tags.take(2).toList(growable: false);
  return [
    for (final tag in visible) ...[
      Flexible(child: _TagBadge(tag: tag)),
      const SizedBox(width: 6),
    ],
    if (tags.length > visible.length) ...[
      _TagMoreBadge(count: tags.length - visible.length),
      const SizedBox(width: 6),
    ],
  ];
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xffeef1e8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_rounded, size: 12, color: _muted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag});

  final SavedTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color(tag.color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_rounded, size: 12, color: Color(tag.color)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(tag.color),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagMoreBadge extends StatelessWidget {
  const _TagMoreBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xfff0f0ec),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
              cacheWidth: 216,
              cacheHeight: 216,
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
