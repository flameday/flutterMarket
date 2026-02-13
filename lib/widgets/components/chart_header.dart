import 'package:flutter/material.dart';
import '../../models/price_data.dart';

/// チャートヘッダーコンポーネント
class ChartHeader extends StatelessWidget {
  final PriceData? hoveredCandle;
  final double? hoveredPrice;
  final double minPrice;
  final double maxPrice;

  const ChartHeader({
    super.key,
    this.hoveredCandle,
    this.hoveredPrice,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  Widget build(BuildContext context) {
    Widget headerContent;
    
    if (hoveredCandle != null && hoveredPrice != null) {
      final candle = hoveredCandle!;
      final o = candle.open.toStringAsFixed(5);
      final h = candle.high.toStringAsFixed(5);
      final l = candle.low.toStringAsFixed(5);
      final c = candle.close.toStringAsFixed(5);
      final v = candle.volume.toStringAsFixed(2);
      
      headerContent = SelectableText(
        '${candle.formattedDateTime}  O: $o  H: $h  L: $l  C: $c  V: $v',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    } else {
      headerContent = SelectableText(
        '価格レンジ: ${minPrice.toStringAsFixed(5)} - ${maxPrice.toStringAsFixed(5)}',
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 10,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight, 
              child: headerContent
            ),
          ),
        ],
      ),
    );
  }
}
