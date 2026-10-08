import 'package:flutter/material.dart';
import 'package:pezhvak/utils/history_tools.dart';

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showRule;
  final String query;
  final VoidCallback onTap;
  const NotificationCard(
      {super.key,
      required this.item,
      required this.showRule,
      required this.query,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final triggered = item['triggered_alarm'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                triggered ? Colors.red.shade100 : Colors.grey.shade100,
            child: Icon(
              triggered ? Icons.notifications_active : Icons.notifications,
              color: triggered ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
          title: HighlightText(
            text: item['app_name'] ?? '',
            query: query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item['title'] ?? '').isNotEmpty)
                HighlightText(
                  text: item['title'] ?? '',
                  query: query,
                  style: const TextStyle(fontSize: 13),
                ),
              HighlightText(
                text: item['text'] ?? '',
                query: query,
                maxLines: 2,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (showRule && matchedRuleLabel(item) != null)
                RuleBadge(label: matchedRuleLabel(item)!),
              Text(formatTimestamp(item['timestamp']),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          trailing: triggered
              ? const Tooltip(
                  message: 'آلارم داشت',
                  child: Icon(Icons.alarm, color: Colors.red, size: 16))
              : const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? Colors.grey.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: disabled ? Colors.grey[400] : color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: disabled ? Colors.grey[400] : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: Colors.orange.withValues(alpha: 0.35),
          color: Colors.orange.shade900,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      textDirection: TextDirection.rtl,
    );
  }
}

class AlarmCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String query;
  final VoidCallback onTap;
  const AlarmCard(
      {super.key,
      required this.item,
      required this.query,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: const Icon(Icons.alarm, color: Colors.red, size: 22),
          ),
          title: HighlightText(
            text: item['app_name'] ?? '',
            query: query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item['title'] ?? '').isNotEmpty)
                HighlightText(
                  text: item['title'] ?? '',
                  query: query,
                  style: const TextStyle(fontSize: 13),
                ),
              HighlightText(
                text: item['text'] ?? '',
                query: query,
                maxLines: 2,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (matchedRuleLabel(item) != null)
                RuleBadge(label: matchedRuleLabel(item)!),
              Text(formatTimestamp(item['timestamp']),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          trailing:
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          isThreeLine: true,
        ),
      ),
    );
  }
}
