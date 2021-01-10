import 'package:flutter/material.dart';

class AnimatedPin extends StatefulWidget {
  AnimatedPin({Key key, @required this.isAnimating});

  final bool isAnimating;

  @override
  _AnimatedPinState createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<AnimatedPin>
    with TickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedPin oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start the animation if isAnimating is now true.
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.forward();
    }

    // Stop the animation if isAnimating is now false.
    if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JumpingContainer(
      controller: _controller,
      child: Icon(
        Icons.place,
        size: 36,
        color: Colors.red,
      ),
    );
  }
}

class JumpingContainer extends AnimatedWidget {
  const JumpingContainer({
    Key key,
    @required AnimationController controller,
    @required this.child,
  }) : super(key: key, listenable: controller);

  Animation<double> get _progress => listenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -10 + _progress.value * 10),
      child: child,
    );
  }
}
