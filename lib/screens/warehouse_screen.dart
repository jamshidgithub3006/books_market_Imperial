import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/api_service.dart';

import '../models/material_model.dart';



// Sklad ma'lumotlarini olib keluvchi Provayder

final warehouseProvider = FutureProvider<List<MaterialItem>>((ref) async {

  final apiService = ref.read(apiServiceProvider);

  final data = await apiService.getAll("materials");

  return data.map((json) => MaterialItem.fromJson(json)).toList();

});



// Qidiruv uchun provayder

final warehouseSearchProvider = StateProvider<String>((ref) => '');



class WarehouseScreen extends ConsumerStatefulWidget {

  const WarehouseScreen({super.key});



  @override

  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();

}



class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {

// ULTRA UI Ranglari (Navy Blue & Orange accent)

  final Color bgLight = const Color(0xFFF8FAFC);

  final Color primaryNavy = const Color(0xFF0F172A);

  final Color accentOrange = const Color(0xFFEA580C);

  final Color cardWhite = Colors.white;

  void _showUpdateStockDialog(MaterialItem item) {

    final addQtyController = TextEditingController();

    bool isSaving = false;



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) {

        return StatefulBuilder(

          builder: (context, setState) {

            return AlertDialog(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

              title: Text("${item.name} - Kirim qilish"),

              content: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Text("Hozirgi qoldiq: ${item.quantity} ${item.unit}",

                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),

                  const SizedBox(height: 16),

                  TextField(

                    controller: addQtyController,

                    keyboardType: TextInputType.number,

                    decoration: InputDecoration(

                      labelText: "Qancha kiritildi?",

                      hintText: "Masalan: 50",

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

                    ),

                  ),

                ],

              ),

              actions: [

                TextButton(

                  onPressed: isSaving ? null : () => Navigator.pop(context),

                  child: const Text("Bekor qilish"),

                ),

                ElevatedButton(

                  style: ElevatedButton.styleFrom(backgroundColor: accentOrange),

                  onPressed: isSaving ? null : () async {

                    final double addAmount = double.tryParse(addQtyController.text) ?? 0;

                    if (addAmount <= 0) return;



                    setState(() => isSaving = true);

                    try {

                      final api = ref.read(apiServiceProvider);

// Yangi miqdor = Eski miqdor + Yangi kelgan miqdor

                      final double newTotalQty = item.quantity + addAmount;



                      await api.updateData('materials', {

                        'id': item.id,

                        'quantity': newTotalQty,

                      });



                      if (context.mounted) {

                        Navigator.pop(context);

                        ref.refresh(warehouseProvider);

                        ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text("✅ Ombor yangilandi!"), backgroundColor: Colors.green)

                        );

                      }

                    } catch (e) {

                      if (context.mounted) {

                        ScaffoldMessenger.of(context).showSnackBar(

                            SnackBar(content: Text("❌ Xato: $e"), backgroundColor: Colors.red)

                        );

                      }

                    } finally {

                      setState(() => isSaving = false);

                    }

                  },

                  child: isSaving

                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))

                      : const Text("Tasdiqlash", style: TextStyle(color: Colors.white)),

                ),

              ],

            );

          },

        );

      },

    );

  }

// Yangi tovar qo'shish oynasi (Premium Dialog)

  void _showAddDialog() {

    final idController = TextEditingController();

    final nameController = TextEditingController();

    final qtyController = TextEditingController();

    final priceController = TextEditingController();



    String selectedType = 'tayyor'; // Asosiy qiymat

    String selectedUnit = 'dona'; // Asosiy qiymat

    bool isSaving = false;



    showDialog(

        context: context,

        barrierDismissible: false,

        builder: (context) {

          return StatefulBuilder(

              builder: (context, setState) {

                return Dialog(

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

                  backgroundColor: cardWhite,

                  child: Container(

                    width: 500,

                    padding: const EdgeInsets.all(32),

                    child: SingleChildScrollView( // Kichik ekranlarda sig'ishi uchun

                      child: Column(

                        mainAxisSize: MainAxisSize.min,

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

// Header

                          Row(

                            children: [

                              Container(

                                  padding: const EdgeInsets.all(12),

                                  decoration: BoxDecoration(color: accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),

                                  child: Icon(Icons.add_box_rounded, color: accentOrange, size: 28)

                              ),

                              const SizedBox(width: 16),

                              const Text("Yangi Tovar Qo'shish", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),

                            ],

                          ),

                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),



// Form Inputs

                          _buildInput("Tovar ID (Ixtiyoriy)", idController, Icons.qr_code, hint: "Bo'sh qolsa avto-generatsiya bo'ladi"),

                          const SizedBox(height: 16),

                          _buildInput("Tovar / Xomashyo nomi", nameController, Icons.inventory_2),

                          const SizedBox(height: 16),



                          Row(

                            children: [

                              Expanded(child: _buildInput("Miqdori", qtyController, Icons.numbers, isNum: true)),

                              const SizedBox(width: 16),

// 🔥 NARX KIRITISH MAYDONI

                              Expanded(child: _buildInput("Sotish Narxi", priceController, Icons.payments, isNum: true, hint: "so'mda")),

                            ],

                          ),

                          const SizedBox(height: 16),



// Dropdowns

                          Row(

                            children: [

                              Expanded(

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    const Text("Turi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),

                                    const SizedBox(height: 8),

                                    DropdownButtonFormField<String>(

                                      value: selectedType,

                                      decoration: InputDecoration(filled: true, fillColor: bgLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),

                                      items: const [

                                        DropdownMenuItem(value: 'tayyor', child: Text('Tayyor Mahsulot')),

                                        DropdownMenuItem(value: 'qog\'oz', child: Text('Qog\'oz (Xomashyo)')),

                                        DropdownMenuItem(value: 'kraska', child: Text('Kraska (Xomashyo)')),

                                        DropdownMenuItem(value: 'boshqa', child: Text('Boshqa')),

                                      ],

                                      onChanged: (val) => setState(() => selectedType = val!),

                                    ),

                                  ],

                                ),

                              ),

                              const SizedBox(width: 16),

                              Expanded(

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    const Text("O'lchov birligi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),

                                    const SizedBox(height: 8),

                                    DropdownButtonFormField<String>(

                                      value: selectedUnit,

                                      decoration: InputDecoration(filled: true, fillColor: bgLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),

                                      items: const [

                                        DropdownMenuItem(value: 'dona', child: Text('Dona')),

                                        DropdownMenuItem(value: 'kg', child: Text('Kilogramm')),

                                        DropdownMenuItem(value: 'metr', child: Text('Metr')),

                                        DropdownMenuItem(value: 'litr', child: Text('Litr')),

                                      ],

                                      onChanged: (val) => setState(() => selectedUnit = val!),

                                    ),

                                  ],

                                ),

                              ),

                            ],

                          ),

                          const SizedBox(height: 32),



// Actions

                          Row(

                            mainAxisAlignment: MainAxisAlignment.end,

                            children: [

                              TextButton(

                                onPressed: isSaving ? null : () => Navigator.pop(context),

                                child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),

                              ),

                              const SizedBox(width: 16),

                              ElevatedButton(

                                style: ElevatedButton.styleFrom(

                                    backgroundColor: accentOrange,

                                    foregroundColor: Colors.white,

                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),

                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))

                                ),

                                onPressed: isSaving ? null : () async {

// Validatsiya

                                  if (nameController.text.isEmpty || qtyController.text.isEmpty || priceController.text.isEmpty) {

                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barcha maydonlarni to'ldiring!"), backgroundColor: Colors.orange));

                                    return;

                                  }



                                  setState(() => isSaving = true);

                                  try {

                                    Map<String, dynamic> newData = {

                                      "name": nameController.text.trim(),

                                      "type": selectedType,

                                      "quantity": double.parse(qtyController.text.trim()),

                                      "price": double.parse(priceController.text.trim()), // 🔥 Narxni yuborish

                                      "unit": selectedUnit,

                                    };



                                    if (idController.text.trim().isNotEmpty) {

                                      newData["id"] = idController.text.trim();

                                    }



                                    final success = await ref.read(apiServiceProvider).addData("materials", newData);



                                    if (success && context.mounted) {

                                      Navigator.pop(context);

                                      ref.refresh(warehouseProvider);

                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Skladga muvaffaqiyatli qo'shildi!"), backgroundColor: Colors.green));

                                    }

                                  } catch (e) {

                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Xato: $e"), backgroundColor: Colors.red));

                                  } finally {

                                    setState(() => isSaving = false);

                                  }

                                },

                                child: isSaving

                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))

                                    : const Text('Skladga Saqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                              ),

                            ],

                          ),

                        ],

                      ),

                    ),

                  ),

                );

              }

          );

        }

    );

  }



  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isNum = false, String? hint}) {

    return TextFormField(

      controller: ctrl,

      keyboardType: isNum ? TextInputType.number : TextInputType.text,

      decoration: InputDecoration(

        labelText: label,

        hintText: hint,

        prefixIcon: Icon(icon, color: primaryNavy.withOpacity(0.5)),

        filled: true, fillColor: bgLight,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),

        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentOrange, width: 2)),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final warehouseData = ref.watch(warehouseProvider);

    final searchQuery = ref.watch(warehouseSearchProvider).toLowerCase();



    return Scaffold(

      backgroundColor: bgLight,

      appBar: AppBar(

        title: const Text('OMBORXONA (SKLAD)', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),

        backgroundColor: primaryNavy,

        elevation: 0,

        iconTheme: const IconThemeData(color: Colors.white),

        actions: [

          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(warehouseProvider)),

          const SizedBox(width: 16),

        ],

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: _showAddDialog,

        backgroundColor: accentOrange,

        foregroundColor: Colors.white,

        icon: const Icon(Icons.add),

        label: const Text("Tovar Qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),

      ),

      body: Center(

        child: ConstrainedBox(

          constraints: const BoxConstraints(maxWidth: 1100),

          child: warehouseData.when(

            loading: () => Center(child: CircularProgressIndicator(color: accentOrange)),

            error: (err, stack) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),

            data: (allItems) {

              if (allItems.isEmpty) {

                return Center(

                  child: Column(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),

                      const SizedBox(height: 16),

                      Text("Sklad bo'm-bo'sh. Yangi tovar qo'shing.", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),

                    ],

                  ),

                );

              }



// Qidiruv va Filtr

              final items = allItems.where((i) => i.name.toLowerCase().contains(searchQuery) || i.id.toLowerCase().contains(searchQuery) || i.type.toLowerCase().contains(searchQuery)).toList();



// Statistika hisoblari

              final totalItems = allItems.length;

              final lowStockItems = allItems.where((i) => i.quantity <= 10).length;



              return Column(

                children: [

                  const SizedBox(height: 24),



// Asosiy boshqaruv paneli (Qidiruv + Stats)

                  Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 24.0),

                    child: Row(

                      children: [

// Qidiruv

                        Expanded(

                          flex: 3,

                          child: TextField(

                            onChanged: (val) => ref.read(warehouseSearchProvider.notifier).state = val,

                            decoration: InputDecoration(

                              hintText: "ID, Nomi yoki Turi orqali qidiring...",

                              prefixIcon: Icon(Icons.search, color: primaryNavy),

                              filled: true, fillColor: cardWhite,

                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),

                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),

                            ),

                          ),

                        ),

                        const SizedBox(width: 24),



// Statistika qutilari

                        _buildStatBox("Jami Tur", "$totalItems ta", Colors.blue),

                        const SizedBox(width: 16),

                        _buildStatBox("Kam Qolgan", "$lowStockItems ta", Colors.redAccent, isWarning: lowStockItems > 0),

                      ],

                    ),

                  ),



                  const SizedBox(height: 24),



// Ro'yxat (Grid yoki List)

                  Expanded(

                    child: ListView.builder(

                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),

                      itemCount: items.length,

                      itemBuilder: (context, index) {

                        final item = items[index];

                        final isLowStock = item.quantity <= 10;



                        return InkWell( // 🔥 1. BOSILADIGAN QILINDI

                          onTap: () => _showUpdateStockDialog(item), // 🔥 2. UPDATE OYNASINI CHAQIRISH

                          borderRadius: BorderRadius.circular(16),

                          child: Container(

                            margin: const EdgeInsets.only(bottom: 12),

                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(

                              color: isLowStock ? Colors.red.shade50.withOpacity(0.5) : cardWhite,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: isLowStock ? Colors.red.shade200 : Colors.grey.shade200),

                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],

                            ),

                            child: Row(

                              children: [

// Ikonka

                                Container(

                                  width: 50, height: 50,

                                  decoration: BoxDecoration(color: isLowStock ? Colors.red.shade100 : primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),

                                  child: Icon(Icons.inventory, color: isLowStock ? Colors.redAccent : primaryNavy, size: 24),

                                ),

                                const SizedBox(width: 16),



// Ma'lumot

                                Expanded(

                                  flex: 2,

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),

                                      const SizedBox(height: 4),

                                      Text("ID: ${item.id}", style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontFamily: 'monospace')),

                                    ],

                                  ),

                                ),



// Turi (Badge)

                                Expanded(

                                  flex: 1,

                                  child: Align(

                                    alignment: Alignment.centerLeft,

                                    child: Container(

                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),

                                      child: Text(item.type.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),

                                    ),

                                  ),

                                ),



// Qoldiq

                                Column(

                                  crossAxisAlignment: CrossAxisAlignment.end,

                                  children: [

                                    Text("Qoldiq:", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),

                                    const SizedBox(height: 2),

                                    Row(

                                      crossAxisAlignment: CrossAxisAlignment.baseline,

                                      textBaseline: TextBaseline.alphabetic,

                                      children: [

                                        Text("${item.quantity}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isLowStock ? Colors.redAccent : Colors.black87)),

                                        const SizedBox(width: 4),

                                        Text(item.unit, style: TextStyle(fontSize: 14, color: isLowStock ? Colors.redAccent : Colors.grey.shade600, fontWeight: FontWeight.w600)),

                                      ],

                                    ),

                                  ],

                                )

                              ],

                            ),

                          ),

                        );

                      },

                    ),

                  ),

                ],

              );

            },

          ),

        ),

      ),

    );

  }



  Widget _buildStatBox(String label, String value, Color color, {bool isWarning = false}) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

      decoration: BoxDecoration(

        color: isWarning ? Colors.redAccent : cardWhite,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: isWarning ? Colors.redAccent : Colors.grey.shade200),

        boxShadow: isWarning ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(label, style: TextStyle(color: isWarning ? Colors.white70 : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),

          Text(value, style: TextStyle(color: isWarning ? Colors.white : color, fontSize: 20, fontWeight: FontWeight.bold)),

        ],

      ),

    );

  }

}