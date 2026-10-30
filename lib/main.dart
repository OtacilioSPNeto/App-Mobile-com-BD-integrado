
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class Task {
  int? id;
  String name;
  String description;
  String priority; 
  bool isDone;
  Task({
    this.id,
    required this.name,
    required this.description,
    required this.priority,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'priority': priority,
      'isDone': isDone ? 1 : 0, 
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      priority: map['priority'],
      isDone: map['isDone'] == 1,
    );
  }
}



class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
  
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'tasks_db.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        priority TEXT,
        isDone INTEGER
      )
    ''');
  }

 
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }


  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks', orderBy: 'id DESC');


    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }


  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}


void main() {
  WidgetsFlutterBinding.ensureInitialized(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerenciador de Tarefas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TaskListScreen(),
    );
  }
}


class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Task> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

 
  void _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    _allTasks = await DatabaseHelper().getTasks();
    setState(() {
      _isLoading = false;
    });
  }

 
  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'Alta':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'Média':
        return Icons.keyboard_arrow_right_rounded;
      case 'Baixa':
        return Icons.keyboard_double_arrow_down_rounded;
      default:
        return Icons.info_outline;
    }
  }


  void _toggleTaskStatus(Task task) async {
    task.isDone = !task.isDone;
    await DatabaseHelper().updateTask(task);
    _loadTasks(); 
  }


  void _deleteTask(int id) async {
    await DatabaseHelper().deleteTask(id);
    _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        const SnackBar(content: Text('Tarefa excluída com sucesso!')),
      );
    }
  }

  void _navigateToAddEdit(Task? task) {
    Navigator.of(context as BuildContext).push(
      MaterialPageRoute(
        builder: (context) => AddEditTaskScreen(
          taskToEdit: task,
          onTaskSaved: _loadTasks, 
        ),
      ),
    );
  }

 
  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('Nenhuma tarefa para esta categoria.'));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: ListTile(
            leading: Icon(_getPriorityIcon(task.priority),
                color: task.priority == 'Alta'
                    ? Colors.red
                    : task.priority == 'Média'
                        ? Colors.orange
                        : Colors.green),
            title: Text(
              task.name,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(task.description),
            trailing: PopupMenuButton<String>(
              onSelected: (String result) {
                switch (result) {
                  case 'done':
                    _toggleTaskStatus(task);
                    break;
                  case 'edit':
                    _navigateToAddEdit(task);
                    break;
                  case 'delete':
                    _deleteTask(task.id!);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'done',
                  child: Text(task.isDone ? 'Marcar como Pendente' : 'Marcar como Concluída'),
                ),
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Editar'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Excluir'),
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

    final pendingTasks = _allTasks.where((t) => !t.isDone).toList();
    final completedTasks = _allTasks.where((t) => t.isDone).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Tarefas'),
        backgroundColor: Colors.indigo,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Pendentes'),
            Tab(text: 'Concluídas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_allTasks), 
                _buildTaskList(pendingTasks), 
                _buildTaskList(completedTasks), 
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(null),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddEditTaskScreen extends StatefulWidget {
  final Task? taskToEdit; // Se for edição, a tarefa é passada aqui
  final Function onTaskSaved; // Callback para atualizar a lista

  const AddEditTaskScreen({super.key, this.taskToEdit, required this.onTaskSaved});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedPriority; // Prioridade selecionada

  final List<String> _priorities = ['Alta', 'Média', 'Baixa'];

  @override
  void initState() {
    super.initState();
  
    if (widget.taskToEdit != null) {
      _nameController.text = widget.taskToEdit!.name;
      _descriptionController.text = widget.taskToEdit!.description;
      _selectedPriority = widget.taskToEdit!.priority;
    } else {

      _selectedPriority = _priorities.first;
    }
  }


  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final newTask = Task(
        id: widget.taskToEdit?.id,
        name: _nameController.text,
        description: _descriptionController.text,
        priority: _selectedPriority!,
        isDone: widget.taskToEdit?.isDone ?? false,
      );

      if (widget.taskToEdit == null) {
        // Adiciona nova tarefa
        await DatabaseHelper().insertTask(newTask);
      } else {
        // Atualiza tarefa existente
        await DatabaseHelper().updateTask(newTask);
      }

      widget.onTaskSaved();
      if (mounted) Navigator.pop(context as BuildContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit == null ? 'Adicionar Tarefa' : 'Editar Tarefa'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da Tarefa'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome da tarefa';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira uma descrição';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: _priorities.map((String priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPriority = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Por favor, selecione a prioridade';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveTask,
                child: Text(widget.taskToEdit == null ? 'Salvar Tarefa' : 'Atualizar Tarefa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}