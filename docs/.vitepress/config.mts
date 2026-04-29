import { defineConfig } from 'vitepress'

const description =
  'A beautiful, read-only macOS reader for generated Markdown folders.'

export default defineConfig({
  title: 'SkimDown',
  description,

  head: [
    ['link', { rel: 'icon', href: '/images/icon-36.png' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'SkimDown' }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:image', content: '/images/app-screenshot-placeholder.svg' }],
  ],

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Installation', link: '/installation' },
          { text: 'Usage', link: '/usage' },
          { text: 'Privacy', link: '/security' },
          { text: 'GitHub', link: 'https://github.com/07JP27/SkimDown' },
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Installation', link: '/installation' },
              {
                text: 'Usage',
                link: '/usage',
                items: [
                  { text: 'Open folders', link: '/usage/open-folder' },
                  { text: 'Preview', link: '/usage/preview' },
                  { text: 'Search', link: '/usage/search' },
                  { text: 'Live reload', link: '/usage/reload' },
                ],
              },
              { text: 'Privacy & Permissions', link: '/security' },
            ],
          },
        ],
      },
    },
    ja: {
      label: '日本語',
      lang: 'ja',
      description: '生成されたMarkdownフォルダを静かに読み進めるmacOSリーダー',
      themeConfig: {
        nav: [
          { text: 'インストール', link: '/ja/installation' },
          { text: '使い方', link: '/ja/usage' },
          { text: 'プライバシー', link: '/ja/security' },
          { text: 'GitHub', link: 'https://github.com/07JP27/SkimDown' },
        ],
        sidebar: [
          {
            text: 'ガイド',
            items: [
              { text: 'インストール', link: '/ja/installation' },
              {
                text: '使い方',
                link: '/ja/usage',
                items: [
                  { text: 'フォルダを開く', link: '/ja/usage/open-folder' },
                  { text: 'プレビュー', link: '/ja/usage/preview' },
                  { text: '検索', link: '/ja/usage/search' },
                  { text: '自動更新', link: '/ja/usage/reload' },
                ],
              },
              { text: 'プライバシーと権限', link: '/ja/security' },
            ],
          },
        ],
        outline: { label: '目次' },
        docFooter: { prev: '前のページ', next: '次のページ' },
        lastUpdated: { text: '最終更新' },
        returnToTopLabel: 'トップへ戻る',
        darkModeSwitchLabel: 'テーマ',
        langMenuLabel: '言語',
      },
    },
  },

  themeConfig: {
    logo: '/images/icon-36.png',

    socialLinks: [
      { icon: 'github', link: 'https://github.com/07JP27/SkimDown' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'A beautiful reader for generated Markdown.',
      copyright: '© 2026 <a href="https://github.com/07JP27">07JP27</a>',
    },
  },
})
