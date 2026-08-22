import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/overlay_service.dart';

class EventLampOverlay extends StatelessWidget {
    final Widget child;

    const EventLampOverlay({super.key, required this.child});

    @override
    Widget build(BuildContext context) {
        return child;
    }
}
