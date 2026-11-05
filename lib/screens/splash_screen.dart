import 'dart:async';

import 'package:flutter/material.dart';

class NdrlSplashScreen extends StatefulWidget {
  const NdrlSplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<NdrlSplashScreen> createState() => _NdrlSplashScreenState();
}

class _NdrlSplashScreenState extends State<NdrlSplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111111),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: AssetImage('assets/images/ndrl_logo.png'),
                  width: 300,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 28),
                Text(
                  'NOSTALGIA DRAG RACING LEAGUE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'THE HOME OF NOSTALGIA DRAG RACING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD1AC67),
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 44),
                CircularProgressIndicator(
                  color: Color(0xFFB91C1C),
                  strokeWidth: 2,
                ),
                SizedBox(height: 14),
                Text(
                  'Loading NDRL Mobile...',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
