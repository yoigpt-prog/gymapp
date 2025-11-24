class Exercise {
  final String name;
  final int sets;
  final int reps;
  bool completed;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.completed = false,
  });
}
