import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/overlay_service.dart';

class InAppEventLamp extends StatefulWidget {
    const InAppEventLamp({super.key});

    @override
    State<InAppEventLamp> createState() => _InAppEventLampState();
}

class _InAppEventLampState extends State<InAppEventLamp> with SingleTickerProviderStateMixin {
    AnimationController? _animController;
    Animation<double>? _opacityAnim;
    Timer? _hideTimer;

    Color _lampColor = const Color(0xFF00E5FF);
    String _shape = "bar";
    String _position = "topCenter";
    bool _isVisible = false;
    bool _isBlinking = false;

    @override
    void initState() {
        super.initState();
        _animController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
        );
        _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _animController!, curve: Curves.easeInOut),
        );

        OverlayService.inAppLampNotifier.addListener(_onLampTriggered);
    }

    @override
    void dispose() {
        OverlayService.inAppLampNotifier.removeListener(_onLampTriggered);
        _hideTimer?.cancel();
        _animController?.dispose();
        super.dispose();
    }

    void _onLampTriggered() {
        final data = OverlayService.inAppLampNotifier.value;
        if (data == null || !mounted) return;

        final type = data['type'] as String? ?? '5g';
        final shape = data['shape'] as String? ?? 'bar';
        final position = data['position'] as String? ?? 'topCenter';

        final color = type == 'critical'
            ? const Color(0xFFFF1744)
            : type == 'handover'
                ? const Color(0xFFFFB300)
                : const Color(0xFF00E5FF);

        _hideTimer?.cancel();
        _animController?.stop();

        setState(() {
            _lampColor = color;
            _shape = shape;
            _position = position;
            _isVisible = true;
            _isBlinking = (type == 'critical');
        });

        if (_isBlinking) {
            _animController?.repeat(reverse: true);
        } else {
            _animController?.forward(from: 0.0);
        }

        _hideTimer = Timer(const Duration(milliseconds: 2800), () {
            if (mounted) {
                _animController?.reverse().then((_) {
                    if (mounted) {
                        setState(() => _isVisible = false);
                    }
                });
            }
        });
    }

    @override
    Widget build(BuildContext context) {
        if (!_isVisible || _animController == null) {
            return const SizedBox.shrink();
        }

        final size = MediaQuery.of(context).size;
        final isDot = _shape == 'dot';
        final lampWidth = isDot ? 8.0 : (size.width / 2);
        final lampHeight = isDot ? 8.0 : 3.0;
        final cornerRadius = isDot ? 4.0 : 1.5;

        final alignment = _position == 'topLeft'
            ? Alignment.topLeft
            : _position == 'topRight'
                ? Alignment.topRight
                : Alignment.topCenter;

        final margin = _position == 'topLeft'
            ? const EdgeInsets.only(left: 16.0)
            : _position == 'topRight'
                ? const EdgeInsets.only(right: 16.0)
                : EdgeInsets.zero;

        return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
                bottom: false,
                left: false,
                right: false,
                child: Align(
                    alignment: alignment,
                    child: Container(
                        margin: margin,
                        width: lampWidth,
                        height: lampHeight,
                        child: AnimatedBuilder(
                            animation: _opacityAnim!,
                            builder: (context, child) {
                                return Opacity(
                                    opacity: _opacityAnim!.value.clamp(0.0, 1.0),
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: _lampColor,
                                            borderRadius: BorderRadius.circular(cornerRadius),
                                            boxShadow: [
                                                BoxShadow(
                                                    color: _lampColor.withOpacity(0.6),
                                                    blurRadius: 6.0,
                                                    spreadRadius: 1.0,
                                                ),
                                            ],
                                        ),
                                    ),
                                );
                            },
                        ),
                    ),
                ),
            ),
        );
    }
}
