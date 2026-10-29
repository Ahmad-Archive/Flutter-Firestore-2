import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class Task {
  final String id;
  final String title;
  final String detail;

  Task({
    required this.id,
    required this.title,
    required this.detail,
  });

  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? "",
      detail: data['detail'] ?? "",
    );
  }
}

class TaskViewModel extends ChangeNotifier {
  final CollectionReference _tasksCollection =
  FirebaseFirestore.instance.collection('tasks');

  Stream<List<Task>>get tasksStream {
    return _tasksCollection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Task.fromDocument(doc)).toList();
      });
  }

  Future<void> addTask(String title, String detail) async {
    try {
      await _tasksCollection.add({
        'title': title,
        'detail': detail,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error adding task: $e");
    }
  }

  Future<void> updateTask(String id, String title, String detail) async {
    try {
      await _tasksCollection.doc(id).update({
        'title': title,
        'detail': detail,
      });
    } catch (e) {
      debugPrint("Error updating task $e");
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _tasksCollection.doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting task $e");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider (
      providers: [
        ChangeNotifierProvider(create: (_) => TaskViewModel()),
      ],
      child: MaterialApp (
        title: 'Flutter MVVM Provider Firestore',
        theme: ThemeData(primarySwatch: Colors.teal),
        home: const TaskScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  void _showForm(BuildContext context, [Task? task]) {
    if (task != null){
      _titleController.text = task.title;
      _detailController.text = task.detail;
    } else {
      _titleController.clear();
      _detailController.clear();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
          ),
          child: Column (
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul Tugas'),
              ),
              TextField(
                controller: _detailController,
                decoration: const InputDecoration(labelText: 'Detail Tugas'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final title = _titleController.text;
                  final detail = _detailController.text;

                  if (title.isNotEmpty && detail.isNotEmpty) {
                    final viewModel = context.read<TaskViewModel>();

                    if (task == null) {
                      await viewModel.addTask(title, detail);
                    } else {
                      await viewModel.updateTask(task.id, title, detail);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                child: Text(task == null ? 'Simpan' : 'Perbarui'),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<TaskViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('MVVM Firestore Tasks')),
      body: StreamBuilder<List<Task>>(
        stream: viewModel.tasksStream,
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if(!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada tugas'));
          }

          final tasks = snapshot.data!;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card (
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(task.detail),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showForm(context, task),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            viewModel.deleteTask(task.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tugas dihapus')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              );
            }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}