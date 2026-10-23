# Icon attribution

`App/Sources/DesignSystem/WPMaterialIcon.swift` adapts the original 24px SVG paths from [Google Material Design Icons](https://github.com/google/material-design-icons), under the [Apache License 2.0](material-design-icons.txt).

The icons preserve the Android reference shapes. The source category/style is recorded by the corresponding Material icon name.

## Invitation display type

`NotoSerif-Regular.ttf` and `NotoSerif-Italic.ttf` are unmodified Android API 35 system fonts (`/system/fonts`), bundled to preserve the Android invitation's serif letterforms on iOS. Their embedded copyright is “Copyright 2012 Google Inc. All Rights Reserved.” and their name-table license is SIL Open Font License 1.1. The copyright and license accompany the fonts in `App/Resources/Fonts/NotoSerif-LICENSE.txt`.

## WebP encoder (feed review photos)

Feed review photos are uploaded as WebP only (the server accepts `image/webp`). iOS ImageIO can decode WebP but cannot encode it, so the app links [Google libwebp](https://chromium.googlesource.com/webm/libwebp) through the [SDWebImage/libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) package (1.6.0), under the [BSD 3-Clause license](libwebp.txt). The license text is also bundled in the app at `App/Resources/Licenses/libwebp-LICENSE.txt`.
