import 'package:flutter/material.dart';
import '../../models/trading_pair.dart';

/// 取引ペア選択コンポーネント
class TradingPairSelector extends StatelessWidget {
  final TradingPair selectedPair;
  final ValueChanged<TradingPair> onPairChanged;
  final bool enabled;

  const TradingPairSelector({
    super.key,
    required this.selectedPair,
    required this.onPairChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TradingPair>(
          value: selectedPair,
          onChanged: enabled ? (value) => onPairChanged(value!) : null,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          items: TradingPair.values.map((pair) {
            return DropdownMenuItem<TradingPair>(
              value: pair,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPairColor(pair),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          pair.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SelectableText(
                          pair.description,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(pair.category),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      pair.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getPairColor(TradingPair pair) {
    switch (pair) {
      case TradingPair.eurusd:
        return Colors.blue;
      case TradingPair.usdjpy:
        return Colors.red;
      case TradingPair.gbpjpy:
        return Colors.orange;
      case TradingPair.xauusd:
        return Colors.amber;
      case TradingPair.gbpusd:
        return Colors.green;
      case TradingPair.audusd:
        return Colors.purple;
      case TradingPair.usdcad:
        return Colors.cyan;
      case TradingPair.nzdusd:
        return Colors.pink;
      case TradingPair.eurjpy:
        return Colors.indigo;
      case TradingPair.eurgbp:
        return Colors.teal;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '主要通貨ペア':
        return Colors.blue[700]!;
      case 'クロス円':
        return Colors.red[700]!;
      case '貴金属':
        return Colors.amber[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}
