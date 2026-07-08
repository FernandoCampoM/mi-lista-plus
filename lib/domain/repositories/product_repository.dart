import '../entities/country.dart';
import '../entities/product.dart';
import '../entities/simulation.dart';

abstract interface class ProductRepository {
  Future<List<Country>> getCountries();
  Future<List<Product>> loadProducts(String countryCode);
  Future<void> syncProductsIfNeeded(String countryCode);
  Future<void> saveSelectedCountry(String countryCode);
  Future<String?> getSelectedCountry();
  Future<void> saveSimulation(Simulation simulation);
  Future<List<Simulation>> loadSimulations(String countryCode);
  Future<void> deleteSimulation(String countryCode, String simulationId);
  Future<void> deleteSimulations(String countryCode, Set<String> simulationIds);
}
