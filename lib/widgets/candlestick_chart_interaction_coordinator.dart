part of 'candlestick_chart.dart';

class _CandlestickChartInteractionCoordinator {
  const _CandlestickChartInteractionCoordinator._();

  static void onPointerDown(_CandlestickChartState state, PointerDownEvent event) {
    if (event.buttons != kSecondaryMouseButton) return;

    _armRightClickDeleteGuard(state);

    final RenderBox renderBox = _chartRenderBox(state);
    final Offset localPosition = renderBox.globalToLocal(event.position);
    final double chartX = localPosition.dx;
    final double chartWidth = renderBox.size.width;

    if (_handleVerticalLineRightClickDelete(state, chartX, chartWidth)) {
      return;
    }

    _handleKlineSelectionRightClickDelete(state, chartX, chartWidth);
  }

  static void onScaleUpdate(_CandlestickChartState state, ScaleUpdateDetails details) {
    if (state._draggingObjectId != null && state._draggingObjectTarget != null) {
      final Offset localPosition = details.localFocalPoint;
      final geometry = state._resolveChartGeometry();

      state._updateDraggingObject(localPosition, geometry.width, geometry.height);
      return;
    }

    state.setState(() {
      if (state._controller.isKlineCountMode) {
        final RenderBox renderBox = _chartRenderBox(state);
        final Offset localPosition = renderBox.globalToLocal(details.focalPoint);
        state._controller.updateSelection(localPosition.dx);
      } else {
        state._controller.onScaleUpdate(details, state._lastWidth);
      }
    });
  }

  static void onScaleStart(_CandlestickChartState state, ScaleStartDetails details) {
    if (state._isRightClickDeleting) return;

    final Offset localPosition = details.localFocalPoint;
    final geometry = state._resolveChartGeometry();

    if (_tryStartObjectDrag(state, localPosition, geometry.width, geometry.height)) {
      return;
    }

    if (state._controller.isKlineCountMode) {
      state._controller.startSelection(localPosition.dx);
    }
  }

  static void onScaleEnd(_CandlestickChartState state, ScaleEndDetails details) {
    if (state._draggingObjectId != null) {
      state.setState(() {
        _clearDraggingSession(state);
      });
      return;
    }

    if (state._controller.isKlineCountMode) {
      _finishKlineSelectionMode(state);
    }
  }

  static void _armRightClickDeleteGuard(_CandlestickChartState state) {
    state._isRightClickDeleting = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      state._isRightClickDeleting = false;
    });
  }

  static bool _handleVerticalLineRightClickDelete(
    _CandlestickChartState state,
    double chartX,
    double chartWidth,
  ) {
    if (state._controller.verticalLines.isEmpty) return false;
    state._controller.removeVerticalLineNearPosition(chartX, chartWidth).then((deleted) {
      if (deleted) {
        state._refreshUI();
      }
    });
    return true;
  }

  static bool _handleKlineSelectionRightClickDelete(
    _CandlestickChartState state,
    double chartX,
    double chartWidth,
  ) {
    if (!state._controller.isKlineCountMode) return false;
    final selection = state._controller.findKlineSelectionAtPosition(chartX, chartWidth);
    if (selection == null) return false;
    state._controller.removeKlineSelection(selection.id).then((success) {
      if (success) {
        state._refreshUI();
      }
    });
    return true;
  }

  static bool _tryStartObjectDrag(
    _CandlestickChartState state,
    Offset localPosition,
    double chartWidth,
    double chartHeight,
  ) {
    final dragHit = state._hitTestObject(localPosition.dx, localPosition.dy, chartWidth, chartHeight);
    if (dragHit == null) return false;

    state.setState(() {
      state._applyObjectSelectionHit(dragHit);
      state._draggingObjectId = dragHit.objectId;
      state._draggingObjectType = dragHit.objectType;
      state._draggingObjectTarget = dragHit.dragTarget;
      state._lastDragPosition = localPosition;
    });
    return true;
  }

  static void _finishKlineSelectionMode(_CandlestickChartState state) {
    final RenderBox renderBox = _chartRenderBox(state);
    final double chartWidth = renderBox.size.width;
    state._controller.finishSelection(chartWidth);

    if (state._controller.selectedKlineCount > 0) {
      _saveKlineSelectionAndExit(state, chartWidth);
    } else {
      state.setState(() {
        _exitKlineCountMode(state);
      });
    }

    state.setState(() {});
  }

  static void _saveKlineSelectionAndExit(_CandlestickChartState state, double chartWidth) {
    state._controller.saveCurrentSelection(chartWidth).then((success) {
      if (success) {
        state.setState(() {
          _exitKlineCountMode(state);
        });
      }
    });
  }

  static void _exitKlineCountMode(_CandlestickChartState state) {
    state._controller.toggleKlineCountMode();
  }

  static void _clearDraggingSession(_CandlestickChartState state) {
    state._draggingObjectId = null;
    state._draggingObjectType = null;
    state._draggingObjectTarget = null;
    state._lastDragPosition = null;
  }

  static RenderBox _chartRenderBox(_CandlestickChartState state) {
    return state.context.findRenderObject() as RenderBox;
  }
}
