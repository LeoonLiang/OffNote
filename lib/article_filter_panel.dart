import 'package:flutter/material.dart';

import 'article_database.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'saved_tag.dart';

const _filterAccent = Color(0xffd83f5f);
const _filterAccentSoft = Color(0xffffedf2);
const _filterChip = Color(0xfff5f5f5);
const _filterText = Color(0xff242424);
const _filterMuted = Color(0xff727272);

class ArticleFilterSettings {
  const ArticleFilterSettings({
    required this.sort,
    this.starredOnly = false,
    this.uncategorizedOnly = false,
    this.categoryId,
    this.mediaTypes = const {},
    this.tagIds = const {},
  });

  final ArticleSort sort;
  final bool starredOnly;
  final bool uncategorizedOnly;
  final String? categoryId;
  final Set<ArticleMediaType> mediaTypes;
  final Set<String> tagIds;

  ArticleFilterSettings copyWith({
    ArticleSort? sort,
    bool? starredOnly,
    bool? uncategorizedOnly,
    Object? categoryId = _unset,
    Set<ArticleMediaType>? mediaTypes,
    Set<String>? tagIds,
  }) {
    return ArticleFilterSettings(
      sort: sort ?? this.sort,
      starredOnly: starredOnly ?? this.starredOnly,
      uncategorizedOnly: uncategorizedOnly ?? this.uncategorizedOnly,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  static const _unset = Object();
}

class ArticleFilterPanel extends StatelessWidget {
  const ArticleFilterPanel({
    super.key,
    required this.settings,
    required this.categories,
    required this.onChanged,
    required this.onReset,
    required this.onCollapse,
    this.showCategoryFilters = true,
    this.tags = const [],
  });

  final ArticleFilterSettings settings;
  final List<SavedCategory> categories;
  final List<SavedTag> tags;
  final ValueChanged<ArticleFilterSettings> onChanged;
  final VoidCallback onReset;
  final VoidCallback onCollapse;
  final bool showCategoryFilters;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffeeeeee))),
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  title: '排序依据',
                  children: [
                    _OptionChip(
                      label: '发布时间',
                      selected: settings.sort == ArticleSort.publishedNewest,
                      onSelected: () => onChanged(
                        settings.copyWith(sort: ArticleSort.publishedNewest),
                      ),
                    ),
                    _OptionChip(
                      label: '最近保存',
                      selected: settings.sort == ArticleSort.savedNewest,
                      onSelected: () => onChanged(
                        settings.copyWith(sort: ArticleSort.savedNewest),
                      ),
                    ),
                    _OptionChip(
                      label: '最早保存',
                      selected: settings.sort == ArticleSort.savedOldest,
                      onSelected: () => onChanged(
                        settings.copyWith(sort: ArticleSort.savedOldest),
                      ),
                    ),
                  ],
                ),
                _Section(
                  title: '笔记类型',
                  children: [
                    _OptionChip(
                      label: '不限',
                      selected: settings.mediaTypes.isEmpty,
                      onSelected: () =>
                          onChanged(settings.copyWith(mediaTypes: const {})),
                    ),
                    _OptionChip(
                      label: '图文',
                      selected: settings.mediaTypes.contains(
                        ArticleMediaType.image,
                      ),
                      onSelected: () =>
                          _toggleMediaType(ArticleMediaType.image),
                    ),
                    _OptionChip(
                      label: '视频',
                      selected: settings.mediaTypes.contains(
                        ArticleMediaType.video,
                      ),
                      onSelected: () =>
                          _toggleMediaType(ArticleMediaType.video),
                    ),
                  ],
                ),
                _Section(
                  title: '搜索范围',
                  children: [
                    _OptionChip(
                      label: '不限',
                      selected:
                          !settings.starredOnly &&
                          !settings.uncategorizedOnly &&
                          settings.categoryId == null,
                      onSelected: () => onChanged(
                        settings.copyWith(
                          starredOnly: false,
                          uncategorizedOnly: false,
                          categoryId: null,
                        ),
                      ),
                    ),
                    _OptionChip(
                      label: '星标',
                      selected: settings.starredOnly,
                      onSelected: () => onChanged(
                        settings.copyWith(starredOnly: !settings.starredOnly),
                      ),
                    ),
                    if (showCategoryFilters)
                      _OptionChip(
                        label: '未分类',
                        selected: settings.uncategorizedOnly,
                        onSelected: () => onChanged(
                          settings.copyWith(
                            uncategorizedOnly: !settings.uncategorizedOnly,
                            categoryId: null,
                          ),
                        ),
                      ),
                    if (showCategoryFilters)
                      ...categories.map(
                        (category) => _OptionChip(
                          label: category.name,
                          selected: settings.categoryId == category.id,
                          onSelected: () => onChanged(
                            settings.copyWith(
                              uncategorizedOnly: false,
                              categoryId: settings.categoryId == category.id
                                  ? null
                                  : category.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (tags.isNotEmpty)
                  _Section(
                    title: '标签',
                    children: [
                      _OptionChip(
                        label: '不限',
                        selected: settings.tagIds.isEmpty,
                        onSelected: () =>
                            onChanged(settings.copyWith(tagIds: const {})),
                      ),
                      ...tags.map(
                        (tag) => _OptionChip(
                          label: tag.name,
                          selected: settings.tagIds.contains(tag.id),
                          onSelected: () => _toggleTag(tag.id),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeeeeee)),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重置'),
                    style: TextButton.styleFrom(
                      foregroundColor: _filterText,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xffeeeeee)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCollapse,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    label: const Text('收起'),
                    style: TextButton.styleFrom(
                      foregroundColor: _filterText,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMediaType(ArticleMediaType type) {
    final next = Set<ArticleMediaType>.of(settings.mediaTypes);
    if (!next.add(type)) {
      next.remove(type);
    }
    if (next.length == ArticleMediaType.values.length) {
      next.clear();
    }
    onChanged(settings.copyWith(mediaTypes: next));
  }

  void _toggleTag(String tagId) {
    final next = Set<String>.of(settings.tagIds);
    if (!next.add(tagId)) {
      next.remove(tagId);
    }
    onChanged(settings.copyWith(tagIds: next));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _filterMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: children),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: SizedBox(
        width: 80,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: _filterChip,
      selectedColor: _filterAccentSoft,
      labelStyle: TextStyle(
        color: selected ? _filterAccent : _filterText,
        fontSize: 15,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => onSelected(),
    );
  }
}
