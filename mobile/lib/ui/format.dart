import 'package:intl/intl.dart';

String timeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return 'Never';
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative) {
    final ahead = diff.abs();
    if (ahead.inMinutes < 1) return 'in a moment';
    if (ahead.inHours < 1) return 'in ${ahead.inMinutes}m';
    if (ahead.inDays < 1) return 'in ${ahead.inHours}h';
    return 'in ${ahead.inDays}d';
  }
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(time);
}

String formatDuration(int? ms) {
  if (ms == null) return '—';
  if (ms < 1000) return '$ms ms';
  if (ms < 60000) return '${(ms / 1000).toStringAsFixed(ms < 10000 ? 2 : 1)} s';
  return '${ms ~/ 60000}m ${((ms % 60000) / 1000).round()}s';
}

String triggerLabel(String? type) => switch (type) {
      'manual' || 'trigger.manual' => 'Manual',
      'trigger.schedule' => 'Schedule',
      'trigger.webhook' => 'Webhook',
      _ => 'Not set',
    };

String shortId(String id) => id.substring(0, 8);
