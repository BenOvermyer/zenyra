import '../models/task_model.dart';

class UpcomingListItem {
  final bool isHeader;
  final DateTime? date;
  final Task? task;

  UpcomingListItem.header(this.date)
      : isHeader = true,
        task = null;
  UpcomingListItem.task(this.task)
      : isHeader = false,
        date = null;
}
