/// 取引ペア（通貨ペア・商品）の定義
enum TradingPair {
  eurusd('EUR/USD', 'eurusd', 'data/EURUSD'),
  usdjpy('USD/JPY', 'usdjpy', 'data/USDJPY'),
  gbpjpy('GBP/JPY', 'gbpjpy', 'data/GBPJPY'),
  xauusd('XAU/USD', 'xauusd', 'data/XAUUSD'),
  gbpusd('GBP/USD', 'gbpusd', 'data/GBPUSD'),
  audusd('AUD/USD', 'audusd', 'data/AUDUSD'),
  usdcad('USD/CAD', 'usdcad', 'data/USDCAD'),
  nzdusd('NZD/USD', 'nzdusd', 'data/NZDUSD'),
  eurjpy('EUR/JPY', 'eurjpy', 'data/EURJPY'),
  eurgbp('EUR/GBP', 'eurgbp', 'data/EURGBP');

  const TradingPair(this.displayName, this.dukascopyCode, this.directoryName);

  final String displayName; // 表示名
  final String dukascopyCode; // Dukascopyでのコード
  final String directoryName; // ディレクトリ名

  /// 取引ペアの説明を取得
  String get description {
    switch (this) {
      case TradingPair.eurusd:
        return 'ユーロ/米ドル';
      case TradingPair.usdjpy:
        return '米ドル/日本円';
      case TradingPair.gbpjpy:
        return '英ポンド/日本円';
      case TradingPair.xauusd:
        return '金/米ドル';
      case TradingPair.gbpusd:
        return '英ポンド/米ドル';
      case TradingPair.audusd:
        return '豪ドル/米ドル';
      case TradingPair.usdcad:
        return '米ドル/カナダドル';
      case TradingPair.nzdusd:
        return 'NZドル/米ドル';
      case TradingPair.eurjpy:
        return 'ユーロ/日本円';
      case TradingPair.eurgbp:
        return 'ユーロ/英ポンド';
    }
  }

  /// 価格の小数点以下の桁数を取得
  int get decimalPlaces {
    switch (this) {
      case TradingPair.xauusd:
        return 0; // 金は整数表示
      case TradingPair.eurusd:
      case TradingPair.gbpusd:
      case TradingPair.audusd:
      case TradingPair.usdcad:
      case TradingPair.nzdusd:
      case TradingPair.eurgbp:
        return 5; // 主要通貨ペアは小数点以下5桁
      case TradingPair.usdjpy:
      case TradingPair.gbpjpy:
      case TradingPair.eurjpy:
        return 3; // 円ペアは小数点以下3桁
    }
  }

  /// 価格の表示フォーマットを取得
  String formatPrice(double price) {
    return price.toStringAsFixed(decimalPlaces);
  }

  /// 取引ペアのカテゴリを取得
  String get category {
    switch (this) {
      case TradingPair.xauusd:
        return '貴金属';
      case TradingPair.eurusd:
      case TradingPair.gbpusd:
      case TradingPair.audusd:
      case TradingPair.usdcad:
      case TradingPair.nzdusd:
      case TradingPair.eurgbp:
        return '主要通貨ペア';
      case TradingPair.usdjpy:
      case TradingPair.gbpjpy:
      case TradingPair.eurjpy:
        return 'クロス円';
    }
  }

  /// デフォルトの取引ペアを取得
  static TradingPair get defaultPair => TradingPair.eurusd;

  /// 文字列から取引ペアを取得
  static TradingPair? fromString(String value) {
    for (TradingPair pair in TradingPair.values) {
      if (pair.dukascopyCode == value.toLowerCase() || 
          pair.directoryName == value.toUpperCase()) {
        return pair;
      }
    }
    return null;
  }
}
