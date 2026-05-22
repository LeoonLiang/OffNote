# OffNote · 离线笔记

在小红书上找好了旅行攻略、美食指南，出门却没有网络？小红书本身不提供离线缓存功能，OffNote 就是为了解决这个问题而诞生的。

它可以将小红书笔记完整保存到本地——包括文字、图片和视频，在没有网络的环境下随时查阅。

目前仅支持解析小红书内容，未来计划兼容更多平台。

## 功能特性

- **笔记缓存** — 保存小红书笔记的标题、正文、图片和视频到本地
- **系统分享** — 接收 Android 系统分享面板的 `text/plain` 内容
- **剪贴板识别** — 应用恢复时自动检测剪贴板中的小红书链接
- **媒体下载** — 保存笔记标题、正文、作者头像、图片、封面和视频
- **离线浏览** — 生成本地 HTML 页面，无需网络即可阅读
- **分类管理** — 为文章指定分类，支持自定义分类颜色
- **全文搜索** — 基于 SQLite FTS5 搜索标题、内容和备注，短查询自动回退 LIKE
- **备注标注** — 为文章添加个人备注
- **存储统计** — 查看 HTML、图片、视频的存储占用明细
- **保存队列** — 后台队列管理多篇文章的抓取任务，实时显示状态

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter / Dart |
| 页面渲染 | webview_flutter |
| 本地数据库 | sqflite (SQLite + FTS5) |
| 网络请求 | dio |
| 视频播放 | media_kit |
| UI 组件 | shadcn_ui |
| 分享接收 | receive_sharing_intent |

## 项目结构

```
lib/
├── main.dart                    # 应用入口与主题配置
├── article_database.dart        # SQLite 数据库操作（迁移、CRUD、搜索）
├── article_capture_service.dart # WebView 页面抓取服务
├── article_snapshot_store.dart  # 媒体下载与文章持久化
├── article_snapshot.dart        # 通用文章数据解析
├── xhs_note_snapshot.dart       # 小红书笔记专用解析
├── xhs_offline_html.dart        # 小红书离线 HTML 生成
├── save_queue.dart              # 后台保存队列控制器
├── saved_article.dart           # 文章数据模型
├── saved_category.dart          # 分类数据模型
├── link_parser.dart             # URL 提取
├── article_storage_stats.dart   # 存储统计计算
├── pages/                       # 页面
│   ├── home_page.dart           # 首页（标签导航、剪贴板检测、分享接收）
│   ├── article_list_page.dart   # 文章列表（分页、搜索）
│   ├── article_detail_page.dart # 文章详情（本地 HTML 渲染）
│   ├── category_page.dart       # 分类管理
│   ├── storage_stats_page.dart  # 存储统计
│   └── save_queue_page.dart     # 保存队列
└── widgets/                     # 可复用组件
```

## 开发

安装依赖：

```sh
flutter pub get
```

静态分析：

```sh
flutter analyze
```

运行测试：

```sh
flutter test
```

构建 Android Debug APK：

```sh
flutter build apk --debug
```