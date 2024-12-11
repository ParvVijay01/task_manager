import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:task_manager/drawer/drawer.dart';
import 'package:task_manager/screens/profile_screen.dart';
import 'package:task_manager/screens/search_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Database _database;
  final List<Map<String, dynamic>> _tasks = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _listenForConnectivityChanges();
  }

  Future<void> _initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tasks.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY, title TEXT, description TEXT, status INTEGER, synced INTEGER DEFAULT 0)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db
              .execute('ALTER TABLE tasks ADD COLUMN synced INTEGER DEFAULT 0');
        }
      },
    );

    await _fetchTasksFromDatabase();
    _syncTasksFromFirebase();
  }

  void _listenForConnectivityChanges() {
    _connectivityStream.listen((List<ConnectivityResult> results) async {
      // Check if any connectivity result indicates connectivity
      if (results.any((result) => result != ConnectivityResult.none)) {
        // Trigger sync if connectivity is available
        await _syncUnsyncedTasks();
      }
    });
  }

  Future<void> _fetchTasksFromDatabase() async {
    final List<Map<String, dynamic>> tasks = await _database.query('tasks');
    setState(() {
      _tasks.clear();
      _tasks.addAll(tasks.map((task) => {
            'id': task['id'],
            'title': task['title'],
            'description': task['description'],
            'status': task['status'] == 1,
            'synced': task['synced'] == 1,
          }));
    });
  }

  Future<void> _syncTasksFromFirebase() async {
    final snapshot = await _firestore.collection('tasks').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      await _database.insert(
        'tasks',
        {
          'id': int.parse(doc.id),
          'title': data['title'],
          'description': data['description'],
          'status': data['status'] ? 1 : 0,
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _fetchTasksFromDatabase();
  }

  Future<void> _syncUnsyncedTasks() async {
    final List<Map<String, dynamic>> unsyncedTasks = await _database.query(
      'tasks',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var task in unsyncedTasks) {
      await _firestore.collection('tasks').doc(task['id'].toString()).set({
        'title': task['title'],
        'description': task['description'],
        'status': task['status'] == 1,
      });

      await _database.update(
        'tasks',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [task['id']],
      );
    }
    await _fetchTasksFromDatabase();
  }

  Future<void> _addTask(String title, String description) async {
    final id = await _database.insert(
      'tasks',
      {
        'title': title,
        'description': description,
        'status': 0,
        'synced': 0,
      },
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _firestore.collection('tasks').doc(id.toString()).set({
        'title': title,
        'description': description,
        'status': false,
      });

      await _database.update(
        'tasks',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await _fetchTasksFromDatabase();
  }

  Future<void> _updateTask(int id, String title, String description) async {
    await _database.update(
      'tasks',
      {'title': title, 'description': description, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _firestore.collection('tasks').doc(id.toString()).update({
        'title': title,
        'description': description,
      });

      await _database.update(
        'tasks',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await _fetchTasksFromDatabase();
  }

  Future<void> _deleteTask(int id) async {
    await _database.delete('tasks', where: 'id = ?', whereArgs: [id]);

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _firestore.collection('tasks').doc(id.toString()).delete();
    }

    await _fetchTasksFromDatabase();
  }

  Future<void> _toggleStatus(int id, bool currentStatus) async {
    await _database.update(
      'tasks',
      {'status': currentStatus ? 0 : 1, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _firestore.collection('tasks').doc(id.toString()).update({
        'status': !currentStatus,
      });

      await _database.update(
        'tasks',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await _fetchTasksFromDatabase();
  }

  void _openBottomSheet({
    required BuildContext buildContext,
    int? id,
    String? currentTitle,
    String? currentDescription,
  }) {
    final TextEditingController titleController =
    TextEditingController(text: currentTitle);
    final TextEditingController descriptionController =
    TextEditingController(text: currentDescription);

    showModalBottomSheet(
      context: buildContext,
      isScrollControlled: true, // Allow the bottom sheet to resize dynamically
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16.0, // Adjust for keyboard height
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration:
                  const InputDecoration(labelText: 'Task Description'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (id == null) {
                      _addTask(titleController.text, descriptionController.text);
                    } else {
                      _updateTask(
                          id, titleController.text, descriptionController.text);
                    }
                    Navigator.of(bottomSheetContext).pop();
                  },
                  child: Text(id == null ? 'Add Task' : 'Update Task'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (ctx, index) {
                final task = _tasks[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(task['title']),
                    subtitle: Text(task['description']),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: Icon(
                            task['status']
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: task['status'] ? Colors.green : Colors.grey,
                          ),
                          onPressed: () =>
                              _toggleStatus(task['id'], task['status']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openBottomSheet(
                            id: task['id'],
                            currentTitle: task['title'],
                            currentDescription: task['description'],
                            buildContext: context,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTask(task['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openBottomSheet(buildContext: context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SearchScreen()));
          } else if (index == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()));
          }
        },
      ),
    );
  }
}
