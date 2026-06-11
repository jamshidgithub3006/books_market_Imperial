import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/task_model.dart';

final tasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final data = await apiService.getAll("topshiriqlar");
  return data.map((json) => TaskItem.fromJson(json)).toList();
});

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final Color bgLight = const Color(0xFFF8FAFC);
  final Color primaryNavy = const Color(0xFF1E3A8A); // Ilovaning asosiy rangi
  final Color cardWhite = Colors.white;

  // Topshiriq qo'shish oynasi (Bottom Sheet)
  void _showAddTaskSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 20, right: 20, top: 24
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Yangi Topshiriq", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                              labelText: "Sarlavha",
                              prefixIcon: const Icon(Icons.task_alt),
                              filled: true, fillColor: bgLight,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: "Batafsil ma'lumot",
                              filled: true, fillColor: bgLight,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: isSaving ? null : () async {
                              if (titleCtrl.text.isEmpty) return;
                              setState(() => isSaving = true);
                              try {
                                await ref.read(apiServiceProvider).addData('topshiriqlar', {
                                  'title': titleCtrl.text,
                                  'description': descCtrl.text,
                                  'status': 'pending',
                                  'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(), // Ertagacha
                                });
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ref.refresh(tasksProvider);
                                }
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                              } finally {
                                setState(() => isSaving = false);
                              }
                            },
                            child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Saqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  // Statusni o'zgartirish (Bajarildi qilib belgilash)
  void _toggleStatus(TaskItem item) async {
    final newStatus = item.status == 'pending' ? 'completed' : 'pending';
    try {
      await ref.read(apiServiceProvider).updateData('topshiriqlar', {
        'id': item.id,
        'status': newStatus
      });
      ref.refresh(tasksProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text('TOPSHIRIQLAR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: primaryNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(tasksProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: data.when(
        loading: () => Center(child: CircularProgressIndicator(color: primaryNavy)),
        error: (err, stack) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Bajariladigan ishlar yo'q.\nDam olishingiz mumkin! 🎉", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isDone = item.status == 'completed';

              return InkWell(
                onTap: () => _toggleStatus(item), // Bosganda status o'zgaradi
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.grey.shade100 : cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDone ? Colors.green.shade200 : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chap tomondagi Icon (Checkbox kabi)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green.shade100 : Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : Icons.access_time_filled,
                          color: isDone ? Colors.green : Colors.orange.shade800,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Asosiy ma'lumotlar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.grey.shade600 : Colors.black87,
                                decoration: isDone ? TextDecoration.lineThrough : null, // Bajarilgan bo'lsa chizib qo'yiladi
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),

                            // Pastki qator (Muddat va Status)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(item.deadline, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isDone ? "Bajarildi" : "Kutilmoqda",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDone ? Colors.green.shade700 : Colors.orange.shade800,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}