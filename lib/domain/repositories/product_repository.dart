import '../entities/country.dart';
import '../entities/inventory_item.dart';
import '../entities/inventory_movement.dart';
import '../entities/product.dart';
import '../entities/sale.dart';
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
  Future<List<InventoryItem>> loadInventory(String countryCode);
  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
  });
  Future<List<Sale>> loadSales(String countryCode);
  Future<void> registerSale(
    String countryCode,
    List<InventoryItem> inventory,
    Sale sale,
  );
  Future<void> saveSalesAndInventory(
    String countryCode,
    List<InventoryItem> inventory,
    List<Sale> sales, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
    bool recordInventoryMovement = true,
  });
}
