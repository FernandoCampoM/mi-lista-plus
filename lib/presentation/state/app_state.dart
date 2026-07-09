import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/simulation.dart';
import '../../domain/repositories/product_repository.dart';

enum HomeTab { products, simulations }

class AppState extends ChangeNotifier {
  AppState(this._repository);

  final ProductRepository _repository;
  final _uuid = const Uuid();

  List<Country> countries = const [];
  Country? selectedCountry;
  List<Product> products = const [];
  List<Simulation> simulations = const [];
  final Map<String, CartItem> _cart = {};
  String? errorMessage;
  bool isLoading = true;
  int selectedDiscount = 0;
  HomeTab tab = HomeTab.products;

  List<CartItem> get cartItems => _cart.values.toList();

  int get cartUnits {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int get cartPoints {
    return cartItems.fold(0, (sum, item) => sum + item.totalPoints);
  }

  double get cartTotal {
    return cartItems.fold(
      0,
      (sum, item) => sum + item.subtotal(selectedDiscount),
    );
  }

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();

    countries = await _repository.getCountries();
    final countryCode = await _repository.getSelectedCountry();
    if (countryCode != null) {
      final storedCountry = countries.firstWhere(
        (country) => country.code == countryCode,
        orElse: () => countries.first,
      );
      await loadCountry(storedCountry, persist: false);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> loadCountry(Country country, {bool persist = true}) async {
    final previousCountry = selectedCountry;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.syncProductsIfNeeded(country.code);
    } catch (error) {
      errorMessage = error.toString();
    }

    final loadedProducts = await _repository.loadProducts(country.code);

    if (loadedProducts.isEmpty) {
      selectedCountry = previousCountry;
      products = const [];
      simulations = const [];
      _cart.clear();
      selectedDiscount = 0;
      errorMessage = '${country.name} no tiene productos disponibles aun.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    selectedCountry = country;
    products = loadedProducts;
    simulations = await _repository.loadSimulations(country.code);
    _cart.clear();
    selectedDiscount = 0;

    if (persist) {
      await _repository.saveSelectedCountry(country.code);
    }

    isLoading = false;
    notifyListeners();
    return true;
  }

  void setTab(HomeTab value) {
    tab = value;
    notifyListeners();
  }

  void setDiscount(int value) {
    selectedDiscount = value;
    notifyListeners();
  }

  void addProduct(Product product, {int quantity = 1}) {
    if (quantity < 1) return;
    final current = _cart[product.id];
    _cart[product.id] = CartItem(
      product: product,
      quantity: (current?.quantity ?? 0) + quantity,
    );
    notifyListeners();
  }

  void decreaseProduct(Product product) {
    final current = _cart[product.id];
    if (current == null) return;
    if (current.quantity <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  int quantityOf(Product product) => _cart[product.id]?.quantity ?? 0;

  Future<Simulation> createSimulation({String customerName = ''}) async {
    if (selectedCountry == null) {
      throw StateError('Debe seleccionar un pais antes de simular.');
    }
    if (_cart.isEmpty) {
      throw StateError('Agrega al menos un producto para simular.');
    }

    final simulation = Simulation(
      id: _uuid.v4().split('-').first,
      countryCode: selectedCountry!.code,
      customerName: customerName.trim().isEmpty ? 'Cliente' : customerName.trim(),
      discountPercent: selectedDiscount,
      createdAt: DateTime.now(),
      items: cartItems,
    );

    await _repository.saveSimulation(simulation);
    simulations = await _repository.loadSimulations(selectedCountry!.code);
    _cart.clear();
    selectedDiscount = 0;
    tab = HomeTab.simulations;
    notifyListeners();
    return simulation;
  }

  Future<void> deleteSimulation(Simulation simulation) async {
    await _repository.deleteSimulation(simulation.countryCode, simulation.id);
    if (selectedCountry != null) {
      simulations = await _repository.loadSimulations(selectedCountry!.code);
    }
    notifyListeners();
  }

  Future<void> deleteSimulations(Set<String> simulationIds) async {
    if (selectedCountry == null || simulationIds.isEmpty) return;
    await _repository.deleteSimulations(selectedCountry!.code, simulationIds);
    simulations = await _repository.loadSimulations(selectedCountry!.code);
    notifyListeners();
  }

  void loadSimulationIntoCart(Simulation simulation) {
    _cart
      ..clear()
      ..addEntries(
        simulation.items.map((item) => MapEntry(item.product.id, item)),
      );
    selectedDiscount = simulation.discountPercent;
    notifyListeners();
  }
}
