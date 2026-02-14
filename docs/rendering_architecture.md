# 渲染架构（两类绘制模型）

## 核心原则

图表渲染逻辑只分两类：

1. **K线背景板（Board）**
   - 负责时间-价格坐标系与底层行情可视化。
   - 包含：网格、K线本体、均线/布林等指标、价格与时间标签、十字光标等。

2. **Object贴层（Sticker Layer）**
   - 负责叠加在背景板上的交互与标注对象。
   - 包含：竖线、趋势线、斐波那契、波峰波谷点、手动高低点、选区、以及各类线段/形状。
   - **所有斜线、形状都属于 Object。**

这与 Windows 窗口绘制、常见绘图软件的“底图 + 贴图”逻辑一致。

## 代码映射

- `lib/widgets/candlestick_painter.dart`
  - 负责背景板绘制与 Object 分层渲染调度。

- `lib/services/chart_object_factory.dart`
  - 统一把业务态数据（趋势线、手动画点、选区等）转换为 `ChartObject`。

- `lib/models/chart_object.dart`
  - 定义 Object 统一抽象和层级：`belowIndicators` / `aboveIndicators` / `interaction`。

- `lib/services/chart_object_interaction_service.dart`
  - 统一处理 Object 的命中测试与拖拽目标判定。

## 演进约束

- 新增任何“线/形/标注/交互图元”时，优先落到 `ChartObject` 体系。
- 避免在 Painter 中新增平行的“临时直绘通道”；旧通道仅用于兼容回退。
- 业务层只描述“对象数据”，不直接耦合 Canvas 绘制细节。