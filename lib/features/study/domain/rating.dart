enum Rating {
  again(1), // Forgot completely
  hard(2), // Remembered with difficulty
  good(3), // Remembered after hesitation
  easy(4); // Remembered instantly

  final int value;

  const Rating(this.value);
}
