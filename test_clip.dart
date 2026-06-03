import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 74,
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, child: _buildAvatar(34)),
              Positioned(left: 20, child: _buildAvatar(34)),
              Positioned(left: 40, child: _buildAvatar(34)),
            ],
          ),
        ),
      ),
    ),
  ));
}

Widget _buildAvatar(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFF0000), width: 2),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
      ],
    ),
  );
}
