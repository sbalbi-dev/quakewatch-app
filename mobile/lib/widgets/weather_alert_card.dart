import 'package:flutter/material.dart';

import '../models/weather_alert.dart';
import '../utils/formatters.dart';

class WeatherAlertCard extends StatelessWidget {
  final WeatherAlert alert;

  const WeatherAlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert.isActive
          ? Colors.orange.withValues(alpha: 0.15)
          : Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: alert.isActive ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.event,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Formatters.dateTime(alert.start)} — ${Formatters.dateTime(alert.end)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (alert.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(alert.description),
            ],
            if (alert.senderName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Fuente: ${alert.senderName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
