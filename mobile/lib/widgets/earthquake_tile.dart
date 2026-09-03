import 'package:flutter/material.dart';

import '../models/earthquake.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class EarthquakeTile extends StatelessWidget {
  final Earthquake earthquake;
  final double? distanceKm;
  final VoidCallback? onTap;

  const EarthquakeTile({
    super.key,
    required this.earthquake,
    this.distanceKm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(earthquake.severity);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Text(
          Formatters.magnitude(earthquake.magnitude),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      title: Text(
        earthquake.place,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          Formatters.relative(earthquake.time),
          'Profundidad ${earthquake.depthKm.round()} km',
          if (distanceKm != null) 'a ${Formatters.distanceKm(distanceKm!)}',
        ].join(' · '),
      ),
      trailing: earthquake.tsunamiWarning
          ? const Tooltip(
              message: 'Alerta de tsunami asociada',
              child: Icon(Icons.tsunami, color: Colors.blueAccent),
            )
          : null,
    );
  }
}
