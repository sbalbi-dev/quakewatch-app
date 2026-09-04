import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/earthquake.dart';
import '../services/earthquake_service.dart';
import '../widgets/earthquake_tile.dart';
import 'earthquake_detail_screen.dart';

class AllEarthquakesScreen extends StatefulWidget {
  const AllEarthquakesScreen({super.key});

  @override
  State<AllEarthquakesScreen> createState() => _AllEarthquakesScreenState();
}

class _AllEarthquakesScreenState extends State<AllEarthquakesScreen> {
  double _minMagnitude = 2.5;
  String _period = 'day';

  List<Earthquake> _earthquakes = [];
  bool _loading = true;
  String? _error;

  static const _periods = {
    'hour': 'Última hora',
    'day': 'Último día',
    'week': 'Última semana',
    'month': 'Último mes',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = context.read<EarthquakeService>();
    try {
      final earthquakes = await service.fetchRecent(
        minMagnitude: _minMagnitude,
        period: _period,
      );
      if (!mounted) return;
      setState(() {
        _earthquakes = earthquakes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: _periods.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _period = value);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<double>(
                  initialValue: _minMagnitude,
                  decoration: const InputDecoration(labelText: 'Magnitud mín.'),
                  items: const [1.0, 2.5, 4.5, 6.0]
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text('M $m+'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _minMagnitude = value);
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_earthquakes.isEmpty) {
      return const Center(child: Text('No hubo sismos en ese rango.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _earthquakes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => EarthquakeTile(
          earthquake: _earthquakes[index],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EarthquakeDetailScreen(earthquake: _earthquakes[index]),
            ),
          ),
        ),
      ),
    );
  }
}
