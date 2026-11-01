String formatAmount(num amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final wholePart = parts[0];
  final decimalPart = parts[1];

  final buffer = StringBuffer();
  for (int i = 0; i < wholePart.length; i++) {
    final digitsLeft = wholePart.length - i;
    buffer.write(wholePart[i]);
    if (digitsLeft > 1 && digitsLeft % 3 == 1) buffer.write(',');
  }
  return '${buffer.toString()}.$decimalPart';
}

String formatPeso(num amount) => '\u20b1${formatAmount(amount)}';