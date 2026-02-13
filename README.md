# EUR/USD K線チャートアプリ

このFlutterアプリケーションは、EUR/USDの5分足価格データをCSVファイルから読み込み、インタラクティブなK線チャートで表示するアプリケーションです。

## 機能

- **K線チャート表示**: 美しいK線チャートで価格データを視覚化
- **インタラクティブ操作**: マウスドラッグ、ズーム、スクロール操作
- **マウスホイールズーム**: マウスホイールでの直感的なズーム操作
- **CSVデータ読み込み**: dukascopy-nodeツールで生成したCSVファイルからデータを読み込み
- **データの重複除去**: 既存データと新しいデータの重複を自動除去
- **K線時間の連続性**: データの時間連続性を保証
- **レスポンシブUI**: Material Design 3を使用したモダンなUI

## プロジェクト構造

```
lib/
├── main.dart                 # アプリケーションのエントリーポイント
├── models/
│   └── price_data.dart      # 価格データのモデルクラス
├── services/
│   ├── csv_service.dart     # 既存CSV読み込みサービス
│   └── csv_data_service.dart # 新しいCSVデータ読み込みサービス
└── widgets/
    ├── candlestick_chart.dart      # K線チャート表示ウィジェット
    ├── candlestick_painter.dart    # K線描画カスタムペインター
    └── chart_view_controller.dart  # チャートの状態管理コントローラー
```

## データ形式

CSVファイルは以下の形式である必要があります：

```csv
timestamp,open,high,low,close,volume
1420149600000,1.21038,1.21059,1.21036,1.21043,78.85
1420149900000,1.21043,1.21043,1.2103,1.2103,41.25
...
```

- `timestamp`: Unixタイムスタンプ（ミリ秒）
- `open`: 始値
- `high`: 高値
- `low`: 安値
- `close`: 終値
- `volume`: ボリューム

## セットアップ

1. **Flutterのインストール**
   ```bash
   # Flutter SDKがインストールされていることを確認
   flutter doctor
   ```

2. **依存関係のインストール**
   ```bash
   flutter pub get
   ```

3. **CSVファイルの生成と配置**
   - dukascopy-nodeツールを使用してCSVファイルを生成
   ```bash
   # 例: EURUSDの5分足データを取得
   npx dukascopy-node -i eurusd -from 2025-08-15 -to 2025-09-05 -t m5 -f csv --volumes true --directory ./EURUSD/m5 --cache true --cache-path ./.dukascopy-cache --batch-size 12 --batch-pause 1000 --retries 3 --retry-on-empty true
   ```
   - 生成されたCSVファイルは `./EURUSD/m5/` ディレクトリに配置される

4. **アプリケーションの実行**
   ```bash
   flutter run
   ```

## 使用技術

- **Flutter**: クロスプラットフォームUIフレームワーク
- **Material Design 3**: モダンなUIデザイン
- **CSV Package**: CSVファイルの読み込みと解析
- **Intl Package**: 日時のフォーマット

## 主要な機能

### K線チャート表示
- 美しいK線チャートで価格データを視覚化
- 右端を原点としたスケーリング
- 固定空白幅と動的K線描画幅の管理

### インタラクティブ操作
- **マウスドラッグ**: チャートのパン操作
- **マウスホイール**: ズーム操作（1.25倍率）
- **キーボード**: +/- キーでのズーム、←→ キーでのスクロール
- **リセット**: R キーでビューをリセット

### データ管理
- **CSV読み込み**: dukascopy-nodeツールで生成したCSVファイルからデータを読み込み
- **重複除去**: 既存データと新しいデータの重複を自動除去
- **時間連続性**: K線時間の連続性を保証
- **データマージ**: 複数のCSVファイルを自動的にマージ

## アーキテクチャ

このアプリケーションは以下の設計原則に従っています：

- **DRY原則**: 重複コードを避け、再利用可能なコンポーネントを作成
- **KISS原則**: シンプルで理解しやすいコード構造
- **SOLID原則**: 単一責任、開放閉鎖、依存性逆転の原則に従った設計
- **YAGNI原則**: 必要最小限の機能実装

## 使用方法

1. **CSVファイルの生成**
   ```bash
   # 複数の通貨ペアのデータを取得
   $symbols = "eurusd","usdjpy","gbpusd","xauusd"
   foreach ($s in $symbols) {
     npx dukascopy-node -i $s -from 2025-08-15 -to 2025-09-05 -t m5 -f csv --volumes true --directory ./$($s.ToUpper())/m5 --cache true --cache-path ./.dukascopy-cache --batch-size 12 --batch-pause 1000 --retries 3 --retry-on-empty true
   }
   ```

2. **アプリケーションの実行**
   ```bash
   flutter run
   ```

3. **データの読み込み**
   - アプリケーション内の「CSV データ読み込み」ボタンをクリック
   - `./EURUSD/m5/` ディレクトリ内のCSVファイルが自動的に読み込まれる

## 最新の更新

### 2025年1月 - 全テキストコピー対応
- 全てのTextウィジェットをSelectableTextに変更
- チャートヘッダー、設定ダイアログ、コントロールパネルのテキストがコピー可能に
- 価格データ、設定値、ラベルなどのテキストを簡単にコピー可能

## 今後の拡張可能性

- 複数の通貨ペア対応
- リアルタイムデータ更新
- テクニカル指標の追加
- データのエクスポート機能
- チャートのカスタマイズ機能

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。