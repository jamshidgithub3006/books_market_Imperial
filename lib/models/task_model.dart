class TaskItem {
  final String id;
  final String title;
  final String description;
  final String deadline;
  final String status;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'].toString(),
      title: json['title'].toString(),
      description: json['description'].toString(),
      deadline: json['deadline'].toString(),
      status: json['status'].toString(),
    );
  }
}