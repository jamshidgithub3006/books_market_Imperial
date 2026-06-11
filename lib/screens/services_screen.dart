import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/service_model.dart';

// Model orqali ma'lumotlarni o'qiydigan provayder
final servicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final data = await apiService.getAll("services");
  return data.map((json) => ServiceItem.fromJson(json)).toList();
});

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Xizmatlar va Narxlar'),
        backgroundColor: Colors.purple.shade100,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(servicesProvider))
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Xatolik: $err')),
        data: (items) => items.isEmpty
            ? const Center(child: Text("Ma'lumot yo'q"))
            : ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index]; // Bu endi ServiceItem obyekti
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.design_services, color: Colors.white)),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${item.id} | Kerakli xomashyo: ${item.materialId} (${item.materialQty} ta)'),
                trailing: Text('${item.price} so\'m', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          },
        ),
      ),
    );
  }
}