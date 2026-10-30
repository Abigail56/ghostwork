// Port of frontend/src/lib/nodes.ts.
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

class KindStyle {
  const KindStyle(this.label, this.color, this.soft);
  final String label;
  final Color color;
  final Color soft;
}

const kindStyles = {
  'trigger': KindStyle('Trigger', Gw.violet, Gw.violetSoft),
  'action': KindStyle('Action', Gw.cyan, Gw.cyanSoft),
  'condition': KindStyle('Condition', Gw.warning, Gw.warningSoft),
};

KindStyle kindStyle(String kind) => kindStyles[kind] ?? kindStyles['action']!;

String kindOf(String type) => type.startsWith('trigger.')
    ? 'trigger'
    : (type.startsWith('condition.') ? 'condition' : 'action');

const nodeIcons = <String, IconData>{
  'trigger.manual': Icons.back_hand_outlined,
  'trigger.schedule': Icons.event_repeat,
  'trigger.webhook': Icons.webhook,
  'action.http_request': Icons.public,
  'action.transform': Icons.shuffle,
  'action.email': Icons.mail_outline,
  'action.slack': Icons.chat_bubble_outline,
  'action.github_issue': Icons.adjust,
  'action.sheets_append': Icons.table_chart_outlined,
  'action.sheets_read': Icons.table_rows_outlined,
  'condition.if': Icons.call_split,
};

const providerIcons = <String, IconData>{
  'smtp': Icons.mail_outline,
  'slack': Icons.chat_bubble_outline,
  'http_auth': Icons.key_outlined,
  'google': Icons.table_chart_outlined,
  'github': Icons.adjust,
};

IconData nodeIcon(String type) => nodeIcons[type] ?? Icons.circle_outlined;

const _operatorLabels = {
  'equals': '=',
  'not_equals': '≠',
  'contains': 'contains',
  'not_contains': "doesn't contain",
  'greater_than': '>',
  'less_than': '<',
  'is_empty': 'is empty',
  'is_not_empty': 'is not empty',
};

/// One line describing what a configured node will do.
String summarize(String type, Map<String, dynamic> c) {
  switch (type) {
    case 'trigger.manual':
      return 'Runs when you start it';
    case 'trigger.schedule':
      final every = (c['every'] as num?)?.toInt() ?? 1;
      final unit = (c['unit'] as String?) ?? 'hours';
      return 'Every $every ${every == 1 ? unit.replaceAll(RegExp(r's$'), '') : unit}';
    case 'trigger.webhook':
      return 'Runs on incoming HTTP POST';
    case 'action.http_request':
      final url = (c['url'] as String?) ?? '';
      if (url.isEmpty) return 'URL not set';
      final parsed = Uri.tryParse(url.replaceAll(RegExp(r'\{\{.*?\}\}'), 'x'));
      final method = c['method'] ?? 'GET';
      if (parsed == null || parsed.host.isEmpty) return '$method $url';
      return '$method ${parsed.host}${parsed.path == '/' ? '' : parsed.path}';
    case 'action.transform':
      final fields = ((c['fields'] as List?) ?? const [])
          .map((f) => (f as Map)['key'])
          .toList();
      return fields.isEmpty ? 'No fields yet' : 'Builds ${fields.join(', ')}';
    case 'action.email':
      final to = ((c['to'] as List?) ?? const []).cast<String>();
      return to.isEmpty ? 'Recipients not set' : 'To ${to.join(', ')}';
    case 'action.slack':
      final text = (c['text'] as String?) ?? '';
      return text.isEmpty
          ? 'Message not set'
          : (text.length > 60 ? text.substring(0, 60) : text);
    case 'action.github_issue':
      final repo = (c['repository'] as String?) ?? '';
      return repo.isEmpty ? 'Repository not set' : 'Issue in $repo';
    case 'action.sheets_append':
    case 'action.sheets_read':
      if ('${c['spreadsheet_id'] ?? ''}'.isEmpty) return 'Spreadsheet not set';
      final range = '${c['sheet_range'] ?? ''}'.isEmpty
          ? 'Sheet1'
          : c['sheet_range'];
      return '${type.endsWith('append') ? 'Add row to' : 'Read'} $range';
    case 'condition.if':
      final left = (c['left'] as String?) ?? '';
      if (left.isEmpty) return 'Condition not set';
      final op = (c['operator'] as String?) ?? 'equals';
      final unary = op == 'is_empty' || op == 'is_not_empty';
      return '${left.replaceAll(RegExp(r'\{\{\s*|\s*\}\}'), '')} ${_operatorLabels[op] ?? ''} ${unary ? '' : (c['right'] ?? '')}'
          .trim();
    default:
      return '';
  }
}

String summarizeNode(NodeDef n) => summarize(n.type, n.config);
