import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MemoApp());

const List<Color> kMemoColors = [
  Color(0xFFFFFFFF),
  Color(0xFFFFF59D),
  Color(0xFFC8E6C9),
  Color(0xFFBBDEFB),
  Color(0xFFF8BBD0),
  Color(0xFFFFE0B2),
];

class Memo {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  bool isPinned;
  int colorIndex;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
        'colorIndex': colorIndex,
      };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        updatedAt: DateTime.parse(json['updatedAt']),
        isPinned: json['isPinned'] ?? false,
        colorIndex: json['colorIndex'] ?? 0,
      );
}

class MemoApp extends StatefulWidget {
  const MemoApp({super.key});

  @override
  State<MemoApp> createState() => _MemoAppState();
}

class _MemoAppState extends State<MemoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeMode == ThemeMode.dark;
    setState(() => _themeMode = isDark ? ThemeMode.light : ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatin',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MemoListPage(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MemoListPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const MemoListPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  static const String _storageKey = 'memos';
  List<Memo> _memos = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  Future<void> _loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List list = jsonDecode(data);
      setState(() {
        _memos = list.map((e) => Memo.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_memos.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  List<Memo> get _visibleMemos {
    final q = _query.toLowerCase();
    final result = _memos.where((m) {
      return m.title.toLowerCase().contains(q) ||
          m.content.toLowerCase().contains(q);
    }).toList();

    // yang di-pin selalu di atas
    result.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  Future<void> _openEditor({Memo? memo}) async {
    final result = await Navigator.push<Memo>(
      context,
      MaterialPageRoute(builder: (_) => MemoEditPage(memo: memo)),
    );
    if (result == null) return;

    setState(() {
      final index = _memos.indexWhere((m) => m.id == result.id);
      if (index >= 0) {
        _memos[index] = result;
      } else {
        _memos.add(result);
      }
    });
    await _saveMemos();
  }

  Future<void> _togglePin(Memo memo) async {
    setState(() => memo.isPinned = !memo.isPinned);
    await _saveMemos();
  }

  // dihapus lewat geser, bisa dibatalkan dari snackbar
  Future<void> _deleteMemo(Memo memo) async {
    setState(() => _memos.removeWhere((m) => m.id == memo.id));
    await _saveMemos();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catatan "${memo.title}" dihapus'),
        action: SnackBarAction(
          label: 'BATAL',
          onPressed: () async {
            setState(() => _memos.add(memo));
            await _saveMemos();
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final memos = _visibleMemos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatin'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'Mode terang' : 'Mode gelap',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: memos.isEmpty
                ? Center(
                    child: Text(
                      _memos.isEmpty
                          ? 'Belum ada catatan.\nTekan + untuk menambah.'
                          : 'Catatan tidak ditemukan.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                    itemCount: memos.length,
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return Dismissible(
                        key: ValueKey(memo.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteMemo(memo),
                        child: _buildCard(memo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Catatan'),
      ),
    );
  }

  Widget _buildCard(Memo memo) {
    return Card(
      color: kMemoColors[memo.colorIndex],
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openEditor(memo: memo),
        title: Text(
          memo.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${memo.content}\n${_formatDate(memo.updatedAt)}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: memo.isPinned ? 'Lepas pin' : 'Pin catatan',
          icon: Icon(
            memo.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: Colors.black54,
          ),
          onPressed: () => _togglePin(memo),
        ),
      ),
    );
  }
}

class MemoEditPage extends StatefulWidget {
  final Memo? memo;
  const MemoEditPage({super.key, this.memo});

  @override
  State<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends State<MemoEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late int _colorIndex;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController =
        TextEditingController(text: widget.memo?.content ?? '');
    _colorIndex = widget.memo?.colorIndex ?? 0;
    _isPinned = widget.memo?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final memo = Memo(
      id: widget.memo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      updatedAt: DateTime.now(),
      isPinned: _isPinned,
      colorIndex: _colorIndex,
    );
    Navigator.pop(context, memo);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.memo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          IconButton(
            tooltip: _isPinned ? 'Lepas pin' : 'Pin catatan',
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            tooltip: 'Simpan',
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kMemoColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final selected = i == _colorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kMemoColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.blue : Colors.grey,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.black87)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Isi catatan',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}