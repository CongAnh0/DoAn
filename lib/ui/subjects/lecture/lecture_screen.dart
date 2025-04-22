import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LectureScreen extends StatefulWidget {
  final String courseId;
  final String? userRole; // Nhận userRole từ CourseDetailScreen

  const LectureScreen({
    super.key,
    required this.courseId,
    this.userRole,
  });

  @override
  State<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends State<LectureScreen> {
  List<Map<String, dynamic>> _lectures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref().child('courses/${widget.courseId}/lectures');
      final snapshot = await dbRef.once();

      setState(() {
        _isLoading = false;
        if (snapshot.snapshot.value != null) {
          final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
          _lectures = data.entries.map((entry) {
            return {
              'id': entry.key.toString(),
              ...(entry.value as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)),
            };
          }).toList();
          _lectures.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bài giảng: $e')),
      );
    }
  }

  Future<void> _navigateToAddLecture() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLectureScreen(courseId: widget.courseId),
      ),
    );

    if (result == true) {
      await _loadLectures();
    }
  }

  Future<void> _deleteLecture(String lectureId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('courses/${widget.courseId}/lectures/$lectureId')
          .remove();
      _loadLectures();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa bài giảng: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.userRole == 'teacher'
          ? FloatingActionButton(
        onPressed: _navigateToAddLecture,
        child: const Icon(Icons.add),
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lectures.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Chưa có bài giảng nào',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (widget.userRole == 'teacher') ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToAddLecture,
                child: const Text('Thêm bài giảng đầu tiên'),
              ),
            ],
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadLectures,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _lectures.length,
          itemBuilder: (context, index) {
            final lecture = _lectures[index];
            return _buildLectureCard(lecture);
          },
        ),
      ),
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoId: YoutubePlayer.convertUrlToId(lecture['videoUrl']) ?? '',
                title: lecture['title'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_library, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lecture['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.userRole == 'teacher')
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteLecture(lecture['id']),
                    ),
                ],
              ),
              if (lecture['description'] != null && lecture['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    lecture['description'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      lecture['teacherName'] ?? 'Giáo viên',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(lecture['createdAt']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _confirmDeleteLecture(String lectureId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa bài giảng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteLecture(lectureId);
    }
  }
}

class AddLectureScreen extends StatefulWidget {
  final String courseId;

  const AddLectureScreen({super.key, required this.courseId});

  @override
  State<AddLectureScreen> createState() => _AddLectureScreenState();
}

class _AddLectureScreenState extends State<AddLectureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();
  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm bài giảng mới'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitLecture,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin bài giảng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề bài giảng *',
                  border: OutlineInputBorder(),
                  hintText: 'Nhập tiêu đề bài giảng',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề bài giảng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Link YouTube *',
                  border: OutlineInputBorder(),
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập link YouTube';
                  }
                  if (YoutubePlayer.convertUrlToId(value) == null) {
                    return 'Link YouTube không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả bài giảng',
                  border: OutlineInputBorder(),
                  hintText: 'Nhập mô tả chi tiết (nếu có)',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitLecture,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'LƯU BÀI GIẢNG',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitLecture() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final videoId = YoutubePlayer.convertUrlToId(_videoUrlController.text);
      if (videoId == null) {
        throw 'Link YouTube không hợp lệ';
      }

      final dbRef = FirebaseDatabase.instance.ref();
      final lectureRef = dbRef
          .child('courses/${widget.courseId}/lectures')
          .push();

      await lectureRef.set({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'videoUrl': _videoUrlController.text,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'teacherId': _user?.uid,
        'teacherName': _user?.displayName ?? 'Giáo viên',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thêm bài giảng thành công!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm bài giảng: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
        enableCaption: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.blueAccent,
            onReady: () {
              _controller.addListener(() {});
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}