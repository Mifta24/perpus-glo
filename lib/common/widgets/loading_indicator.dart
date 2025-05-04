import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/constants/app_colors.dart';

// loading_indicator.dart digunakan untuk menampilkan
// indikator pemuatan (loading indicator) di aplikasi.
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color color;

  const LoadingIndicator({
    super.key, 
    this.size = 24.0,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SpinKitFadingCircle(
        color: color,
        size: size,
      ),
    );
  }
}