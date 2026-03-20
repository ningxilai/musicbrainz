# musicbrainz.el

Emacs Lisp MusicBrainz API查询库，及其Org-mode 前端。

## 特性

- 13 种实体：search / lookup / browse
- 异步交互：pdd.el 做 HTTP，async.el 做格式化，Emacs 不阻塞
- Org 插入：自动构建 heading + PROPERTIES drawer + MusicBrainz 链接
- Cover Art：插入封面图片链接，Org 内联显示
- Genre：缓存到本地文件，异步刷新
- 速率控制：Token Bucket，15 请求 / 18 秒
- 错误处理：HTTP 503 自动重试，网络错误优雅降级

## 依赖

- Emacs 27.1+
- org-mode 9.0+
- pdd.el 0.2.3+
- async.el 1.9+

## 文件结构

```
musicbrainz/
├── musicbrainz.el       # API 客户端：HTTP、EIEIO、缓存、速率限制
├── musicbrainz-org.el   # Org 前端：异步插入、选择 UI、genre 管理
├── musicbrainz-url.el   # 声明式 URL 模板
└── README.md
```

## 快速开始

```elisp
(require 'musicbrainz-org)

;; 交互式插入（异步，不阻塞 Emacs）
M-x musicbrainz-org-insert-artist
M-x musicbrainz-org-insert-release
M-x musicbrainz-org-insert-tracklist-for-release
M-x musicbrainz-org-insert-cover-art
M-x musicbrainz-org-insert-genre

;; 编程调用
(musicbrainz-search-artist "Miles Davis" 10)
(musicbrainz-lookup-release "mbid-string")
(musicbrainz-browse-artist-releases "artist-mbid" 50)
(musicbrainz-cover-art-url "release-mbid" 500)
```

## 交互流程

```
M-x musicbrainz-org-insert-artist
  → 输入查询词
  → pdd 异步 HTTP（Emacs 响应所有输入）
  → async-start 子进程格式化 100 条候选
  → completing-read 选择
  → 插入 Org heading + 属性 + 链接
```

## 实体速查

| 实体 | 搜索 | 查找 | Browse | Org 插入 |
|------|------|------|--------|----------|
| Artist | `search-artist` | `lookup-artist` | `browse-area-artists` | `insert-artist` |
| Release | `search-release` | `lookup-release` | `browse-artist-releases` | `insert-release` |
| Release Group | `search-release-group` | `lookup-release-group` | `browse-artist-release-groups` | `insert-release-group` |
| Recording | `search-recording` | `lookup-recording` | `browse-artist-recordings` | `insert-recording` |
| Label | `search-label` | `lookup-label` | `browse-area-labels` | `insert-label` |
| Work | `search-work` | `lookup-work` | `browse-artist-works` | `insert-work` |
| Area | `search-area` | `lookup-area` | — | `insert-area` |
| Event | `search-event` | `lookup-event` | `browse-artist-events` | `insert-event` |
| Instrument | `search-instrument` | `lookup-instrument` | — | `insert-instrument` |
| Place | `search-place` | `lookup-place` | — | `insert-place` |
| Series | `search-series` | `lookup-series` | — | `insert-series` |
| URL | `search-url` | `lookup-url` | `lookup-url-by-resource` | `insert-url` |
| Genre | `browse-genres` | `lookup-genre` | — | `insert-genre` |

## Genre

MusicBrainz API 不支持直接搜索 genre。支持三种获取方式：

```elisp
;; 1. 通过 release 获取 genres
(musicbrainz-org-insert-genre-from-release "Kind of Blue")

;; 2. 通过 artist 获取 genres
(musicbrainz-org-insert-genre-from-artist "Miles Davis")

;; 3. 浏览所有 genres（使用本地缓存）
M-x musicbrainz-org-insert-genre
M-x musicbrainz-org-refresh-genre-cache
```

## Cover Art

通过 Cover Art Archive 获取封面：

```elisp
;; 交互式：搜索 release → 选择 → 插入图片链接
M-x musicbrainz-org-insert-cover-art

;; 获取 URL
(musicbrainz-cover-art-url "mbid" 500)   ; 500px 缩略图
(musicbrainz-cover-art-url "mbid")        ; 原图

;; 手动插入
[[https://coverartarchive.org/release/{mbid}/front-500]]
```

Org 中用 `C-c C-x C-v` 切换图片内联显示。

## Org 输出示例

```org
** Kind of Blue
:PROPERTIES:
:ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
:TYPE: Album
:COUNTRY: US
:DATE: 1959-08-17
:STATUS: Official
:FORMAT: CD
:ARTIST: Miles Davis
:END:
*** Artist Credit
  - Miles Davis
*** Tracklist
  - So What
  - Freddie Freeloader
  - Blue in Green
  - All Blues
  - Flamenco Sketches
[[https://musicbrainz.org/release/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx][MusicBrainz Release]]

** Cover Art
[[https://coverartarchive.org/release/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/front-500]]
```

## 配置

```elisp
;; 速率限制
(setq musicbrainz-rate-limit-requests 15)  ; 请求数
(setq musicbrainz-rate-limit-period 18)    ; 秒

;; 缓存
(setq musicbrainz-cache-size 100)          ; LRU 缓存条目数
(setq musicbrainz-genre-cache-file "~/.emacs.d/musicbrainz-genres.eld")

;; Org
(setq musicbrainz-org-default-level 2)     ; 默认 heading 级别
(setq musicbrainz-org-insert-properties t) ; 插入 PROPERTIES drawer
(setq musicbrainz-org-link-to-source t)    ; 插入 MusicBrainz 链接

;; 键绑定
(define-key org-mode-map (kbd "C-c m a") #'musicbrainz-org-insert-artist)
(define-key org-mode-map (kbd "C-c m r") #'musicbrainz-org-insert-release)
(define-key org-mode-map (kbd "C-c m t") #'musicbrainz-org-insert-tracklist-for-release)
(define-key org-mode-map (kbd "C-c m g") #'musicbrainz-org-insert-genre)
(define-key org-mode-map (kbd "C-c m c") #'musicbrainz-org-insert-cover-art)
```

## 参考

- [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API) and [MusicBrainz API Rate Limiting](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting)
- [Cover Art Archive](https://coverartarchive.org)

## License

[MIT](./LICENSE)
