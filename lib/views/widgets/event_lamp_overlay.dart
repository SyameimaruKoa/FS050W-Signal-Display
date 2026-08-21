import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/overlay_service.dart';

class EventLampOverlay extends StatefulWidget {
    final Widget child;

    const EventLampOverlay({super.key, required this.child});

    @override
    State<EventLampOverlay> createState() => _EventLampOverlayState();
}

class _EventLampOverlayState extends State<EventLampOverlay> with SingleTickerProviderStateMixin {
    late AnimationController _animController;
    late Animation<double> _opacityAnimation;
    Timer? _dismissTimer;

    bool _isVisible = false;
    Color _lampColor = const Color(0xFF00E5FF);
    String _shape = "bar";
    String _position = "topCenter";
    bool _isBlinking = false;

    @override
    void initState() {
        super.initState();
        _animController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
        );
        _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);

        OverlayService.inAppLampNotifier.addListener(_onLampTriggered);
    }

    @override
    void dispose() {
        OverlayService.inAppLampNotifier.removeListener(_onLampTriggered);
        _animController.dispose();
        _dismissTimer?.cancel();
        super.dispose();
    }

    void _onLampTriggered() {
        final data = OverlayService.inAppLampNotifier.value;
        if (data == null || !mounted) return;

        final type = data['type'] as String? ?? "5g";
        final shape = data['shape'] as String? ?? "bar";
        final position = data['position'] as String? ?? "topCenter";

        Color color;
        bool isBlink = false;
        switch (type) {
            case "5g":
                color = const Color(0xFF00E5FF); // Emerald Cyan
                break;
            case "handover":
                color = const Color(0xFFFFB300); // Amber Gold
                break;
            case "critical":
                color = const Color(0xFFFF1744); // Red
                isBlink = true;
                break;
            default:
                color = const Color(0xFF00E5FF);
        }

        _dismissTimer?.cancel();
        setState(() {
            _isVisible = true;
            _lampColor = color;
            _shape = shape;
            _position = position;
            _isBlinking = isBlink;
        });

        if (isBlink) {
            _animController.repeat(reverse: true, period: const Duration(milliseconds: 300));
        } else {
            _animController.forward(from: 0.0);
        }

        _dismissTimer = Timer(const Duration(milliseconds: 2700), () {
            if (mounted) {
                _animController.stop();
                _animController.reverse().then((_) {
                    if (mounted) {
                        setState(() {
                            _isVisible = false;
                        });
                    }
                });
            }
        });
    }

    Alignment _getAlignment() {
        switch (_position) {
            case "topLeft":
                return Alignment.topLeft;
            case "topRight":
                return Alignment.topRight;
            default:
                return Alignment.topCenter;
        }
    }

    @override
    Widget build(BuildContext context) {
        return Stack(
            children: [
                widget.child,
                if (_isVisible)
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                            child: Padding(
                                padding: EdgeInsets.only(
                                    top: 4.0,
                                    left: _position == "topLeft" ? 16.0 : 0.0,
                                    right: _position == "topRight" ? 16.0 : 0.0,
                                ),
                                child: Align(
                                    alignment: _getAlignment(),
                                    child: FadeTransition(
                                        opacity: _opacityAnimation,
                                        child: Container(
                                            width: _shape == "dot" ? 8.0 : 50.0,
                                            height: _shape == "dot" ? 8.0 : 4.0,
                                            decoration: BoxDecoration(
                                                color: _lampColor,
                                                borderRadius: BorderRadius.circular(_shape == "dot" ? 4.0 : 2.0),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: _lampColor.withOpacity(0.8),
                                                        blurRadius: 8.0,
                                                        spreadRadius: 2.0,
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
            ],
        );
    }
}
