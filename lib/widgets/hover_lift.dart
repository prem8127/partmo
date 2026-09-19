import 'package:flutter/material.dart';

/// Lifts and softly shadows [child] when a mouse hovers over it.
/// Purely a `MouseRegion` listener, so touch devices (phones/tablets)
/// simply never trigger it — safe to use everywhere, but most noticeable
/// on the web/desktop build where a pointer is actually hovering things.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.lift = 4.0,
    this.scale = 1.02,
    this.borderRadius,
  });

  final Widget child;
  final double lift;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _hovering ? -widget.lift : 0.0)
          ..scale(_hovering ? widget.scale : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
