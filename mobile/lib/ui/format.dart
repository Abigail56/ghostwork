import 'package:intl/intl.dart';

/// Same wording as frontend/src/lib/format.ts.
String timeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return 'Never';
  final seconds = time.difference(now ?? DateTime.now()).inSeconds;
  final abs = seconds.abs();
  if (abs < 45) return seconds <= 0 ? 'just now' : 'in a few seconds';
  const units = [('minute', 60), ('hour', 3600), ('day', 86400), ('week', 604800), ('month', 2592000), ('year', 31536000)];
  var unit = 'minute';
  var size = 60;
  for (final (u, s) in units) {
    if (abs >= s) {
      unit = u;
      size = s;
    }
  }
  final n = (abs / size).round();
  if (unit == 'day' && n == 1) return seconds < 0 ? 'yesterday' : 'tomorrow';
  final label = n == 1 ? unit : '${unit}s';
  return seconds < 0 ? '$n $label ago' : 'in $n $label';
}

String formatDateTime(DateTime? t) => t == null ? '—' : DateFormat('MMM d, h:mm:ss a').format(t);

String formatDate(DateTime? t) => t == null ? '—' : DateFormat('MMM d, y').format(t);

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

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
}
