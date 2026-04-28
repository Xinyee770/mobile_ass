import 'package:flutter/material.dart';

class NotificationBadgeButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;

  const NotificationBadgeButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_rounded,
                color: Color(0xFF6B6B6B),
                size: 24.0,
              ),
              onPressed: onPressed,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}