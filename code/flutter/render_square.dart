/// A custom RenderBox, small enough to read in one sitting.
///
/// `SquareBox` sizes its child to the largest square that fits the incoming
/// constraints. Everything a RenderObject must do is here: layout, painting,
/// hit testing, and telling the framework which of those to redo when a
/// property changes.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The widget: immutable configuration, no logic.
class SquareBox extends SingleChildRenderObjectWidget {
  const SquareBox({required this.padding, super.child, super.key});

  final double padding;

  @override
  RenderSquare createRenderObject(BuildContext context) =>
      RenderSquare(padding: padding);

  /// Called instead of createRenderObject when the widget is replaced by a new
  /// one of the same type — the render object is expensive and is kept.
  @override
  void updateRenderObject(BuildContext context, RenderSquare renderObject) {
    renderObject.padding = padding;
  }
}

class RenderSquare extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderSquare({required double padding}) : _padding = padding;

  double get padding => _padding;
  double _padding;

  set padding(double value) {
    if (_padding == value) {
      return;
    }
    _padding = value;
    // The property affects size, so layout must run again. Setting a property
    // without marking anything is the classic custom-render-object bug: the
    // value changes and the screen does not.
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    // Constraints go down: the child is told the square it must fit.
    final double side = constraints.biggest.shortestSide - padding * 2;
    child.layout(
      BoxConstraints.tight(Size(side, side)),
      // parentUsesSize: false lets the framework skip relayout of this box when
      // only the child's size changes. Set it to true only if you read
      // child.size below — here the size is imposed, so it is not needed.
      parentUsesSize: false,
    );

    // Sizes go up.
    size = constraints.constrain(Size(side + padding * 2, side + padding * 2));

    // Parent sets position: the child's offset lives in its parent data.
    final BoxParentData parentData = child.parentData! as BoxParentData;
    parentData.offset = Offset(padding, padding);
  }

  @override
  void setupParentData(RenderObject child) {
    // Every render object that positions children must give them parent data
    // that can carry an offset.
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    final BoxParentData parentData = child.parentData! as BoxParentData;
    context.paintChild(child, offset + parentData.offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) {
      return false;
    }
    final BoxParentData parentData = child.parentData! as BoxParentData;
    // Without this, taps inside the child are swallowed — the render object
    // lays out and paints correctly and simply does not respond.
    return result.addWithPaintOffset(
      offset: parentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  /// Intrinsics are what `IntrinsicHeight` and friends call. They are separate
  /// layout passes, so implementing them badly is a performance bug rather than
  /// a correctness one.
  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? height : 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);
}
