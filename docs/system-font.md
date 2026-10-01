# Androidシステムフォント (Issue #7)

通常画面、グラフ、HUD、PiPの文字と数値は、同じシステムフォントを継承します。フォントファイルはAPKに同梱せず、端末からメモリに読み込みます。

Android 12 (API 31) 以降では、ネイティブの `TextView` のPaintで `TextRunShaper` を使用し、Androidが実際に選択したフォントを取得します。英数字と日本語で別のフォントを選択する場合は、日本語用フォントもフォールバックとして読み込みます。TTCは選択されたインデックスのフェイスを抽出します。

起動時とアプリ復帰時、画面メトリクスの変更時に確認し、フォントデータが変わった場合だけ再登録します。オーバーレイの数値もAndroidのデフォルトTypefaceを使用します。

Android 11以前、またはOEM側のAPIでフォントを取得できない場合は `sans-serif` にフォールバックします。この場合、メーカー独自のフォント設定への追従は保証できません。Flutter標準のフォント探索だけではOEMの設定を取得できないため、フォント名指定のみで完全対応とはしていません。

参照:

- [Flutterのシステムフォント対応Issue](https://github.com/flutter/flutter/issues/48381)
- [TextRunShaper (API 31)](https://developer.android.com/reference/android/graphics/text/TextRunShaper)
- [Font.getBuffer / getTtcIndex](https://developer.android.com/reference/android/graphics/fonts/Font)

## 実機での確認

GitHub ActionsのAndroid CIからAPKを取得し、One UIのフォントスタイルを変更する前後で次を確認してください。

1. ダッシュボード、設定、グラフの日本語と英数字がシステムのフォントと一致する。
2. HUD、PiP、カード型とコンパクト型オーバーレイでも一致する。
3. アプリを起動したまま端末のフォントを変更し、復帰後に反映される。反映されないOEMではアプリ再起動後も確認する。
4. 標準フォントへ戻した場合も反映される。
5. 大きなフォントサイズ、太字設定、画面幅の狭い端末で欠けやオーバーフローがない。

OEM固有の挙動は実機検証が必要です。ユニットテストおよびAPKのビルド成功だけでは、One UIでの反映を確認したことにはなりません。
