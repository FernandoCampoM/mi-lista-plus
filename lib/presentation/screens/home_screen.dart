import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';
import '../widgets/cart_badge_button.dart';
import 'product_list_screen.dart';
import 'simulation_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.adsOf(context).recordHomeVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Productos',
            actions: const [CartBadgeButton()],
          ),
          const AdaptiveBannerAd(
            margin: EdgeInsets.fromLTRB(18, 14, 18, 0),
            maxHeight: 64,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: _Tabs(tab: state.tab),
          ),
          Expanded(
            child: switch (state.tab) {
              HomeTab.products => const _ProductsHome(),
              HomeTab.simulations => const _SimulationList(),
            },
          ),
          const _BottomNav(),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab});

  final HomeTab tab;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Productos',
            selected: tab == HomeTab.products,
            onTap: () => state.setTab(HomeTab.products),
          ),
          _TabButton(
            label: 'Simulaciones',
            selected: tab == HomeTab.simulations,
            onTap: () => state.setTab(HomeTab.simulations),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsHome extends StatelessWidget {
  const _ProductsHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        _CategoryBanner(
          title: 'Nutricion',
          subtitle: 'OMNILIFE',
          colors: const [Color(0xFF301047), Color(0xFF9E39A7)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProductListScreen(categoryName: 'Nutricion'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _CategoryBanner(
          title: 'Belleza',
          subtitle: 'SEYTU',
          colors: const [Color(0xFF652CA7), Color(0xFFD7B4FF)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProductListScreen(categoryName: 'Belleza'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: colors),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(.65),
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulationList extends StatefulWidget {
  const _SimulationList();

  @override
  State<_SimulationList> createState() => _SimulationListState();
}

class _SimulationListState extends State<_SimulationList> {
  final selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.simulations.isEmpty) {
      return const Center(child: Text('Aun no hay simulaciones.'));
    }

    return Container(
      color: const Color(0xFFEDEAF1),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Checkbox(
                  value: selectedIds.length == state.simulations.length,
                  onChanged: (checked) {
                    setState(() {
                      selectedIds
                        ..clear()
                        ..addAll(
                          checked == true
                              ? state.simulations.map((item) => item.id)
                              : const <String>[],
                        );
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'Seleccionar todas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (selectedIds.isNotEmpty)
                  IconButton.filled(
                    onPressed: () async {
                      await state.deleteSimulations(selectedIds);
                      setState(selectedIds.clear);
                    },
                    icon: const Icon(Icons.delete),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              itemCount: state.simulations.length + 1,
              itemBuilder: (context, index) {
                if (index == state.simulations.length) {
                  return const AdaptiveBannerAd(
                    margin: EdgeInsets.only(top: 8, bottom: 10),
                    maxHeight: 72,
                  );
                }

                final simulation = state.simulations[index];
                final selected = selectedIds.contains(simulation.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey(simulation.id),
                    background: _DismissAction(
                      color: AppColors.green,
                      icon: Icons.open_in_new,
                      label: 'Detalle',
                      alignment: Alignment.centerLeft,
                    ),
                    secondaryBackground: _DismissAction(
                      color: AppColors.danger,
                      icon: Icons.delete,
                      label: 'Eliminar',
                      alignment: Alignment.centerRight,
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SimulationDetailScreen(
                              simulation: simulation,
                            ),
                          ),
                        );
                        return false;
                      }

                      await state.deleteSimulation(simulation);
                      setState(() => selectedIds.remove(simulation.id));
                      return true;
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: selected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedIds.add(simulation.id);
                              } else {
                                selectedIds.remove(simulation.id);
                              }
                            });
                          },
                        ),
                        title: Text(
                          simulation.customerName.trim().isEmpty
                              ? 'Cliente'
                              : simulation.customerName.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('Id: ${simulation.id} · Pais: ${simulation.countryCode}'),
                        trailing: Text(
                          '${simulation.createdAt.day}/${simulation.createdAt.month}/${simulation.createdAt.year}',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SimulationDetailScreen(
                              simulation: simulation,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissAction extends StatelessWidget {
  const _DismissAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.purple,
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BottomItem(icon: Icons.inventory_2, label: 'Productos', active: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? AppColors.orange : Colors.white54, size: 22),
        Text(
          label,
          style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
