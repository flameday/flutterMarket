enum DrawingTool {
  none,
  trendLine,
  circle,
  rectangle,
  fibonacci,
  polyline,
}

extension DrawingToolLabel on DrawingTool {
  String get labelZh {
    switch (this) {
      case DrawingTool.none:
        return '关闭';
      case DrawingTool.trendLine:
        return '斜线';
      case DrawingTool.circle:
        return '圆圈';
      case DrawingTool.rectangle:
        return '长方形';
      case DrawingTool.fibonacci:
        return '斐波那契';
      case DrawingTool.polyline:
        return '折线图';
    }
  }
}
