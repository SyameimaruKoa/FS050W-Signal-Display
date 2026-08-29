import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class FlashDotIndicator extends StatefulWidget {
    final dynamic value;
    final Color? dotColor;
    final double size;
    final EdgeInsetsGeometry padding;

    const FlashDotIndicator({
        super.key,
        required this.value,
        this.dotColor,
        this.size = 5.0,
        this.padding = const EdgeInsets.symmetric(horizontal: 4.0),
    });

    @override
    State<FlashDotIndicator> createState() => _FlashDotIndicatorState();
}

class _FlashDotIndicatorState extends State<FlashDotIndicator> with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _opacityAnimation;

    @override
    void initState() {
        super.initState();
        _controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 500),
        );
        _opacityAnimation = TweenSequence<double>([
            TweenSequenceItem(
                tween: Tween<double>(begin: 0.0, end: 0.85).chain(CurveTween(curve: Curves.easeOutQuad)),
                weight: 40,
            ),
            TweenSequenceItem(
                tween: Tween<double>(begin: 0.85, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
                weight: 60,
            ),
        ]).animate(_controller);
    }

    @override
    void didUpdateWidget(covariant FlashDotIndicator oldWidget) {
        super.didUpdateWidget(oldWidget);
        if (widget.value != oldWidget.value && widget.value != null) {
            final apiService = context.read<ApiService?>();
            final isEnabled = apiService?.settings.updateFlashDotEnabled ?? true;
            if (isEnabled) {
                _controller.forward(from: 0.0);
            }
        }
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService?>();
        final isEnabled = apiService?.settings.updateFlashDotEnabled ?? true;
        if (!isEnabled) {
            return const SizedBox.shrink();
        }

        final color = widget.dotColor ?? const Color(0xFF00E5FF);

        return Padding(
            padding: widget.padding,
            child: AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                    final opacity = _opacityAnimation.value;
                    if (opacity <= 0.01) {
                        return SizedBox(
                            width: widget.size,
                            height: widget.size,
                        );
                    }
                    return Opacity(
                        opacity: opacity,
                        child: Container(
                            width: widget.size,
                            height: widget.size,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                    BoxShadow(
                                        color: color.withOpacity(0.6 * opacity),
                                        blurRadius: 3,
                                        spreadRadius: 1,
                                    ),
                                ],
                            ),
                        ),
                    );
                },
            ),
        );
    }
}

