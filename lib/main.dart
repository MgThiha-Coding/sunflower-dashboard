// Full version with added delete button (only additions made, rest preserved)

import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sunflower_dashboard/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blueGrey.shade900,
        hintColor: Colors.amber,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _webImage;
  PlatformFile? _pickedFile;
  bool _isUploading = false;
  bool _isCanceling = false;

  final String cloudName = "dabxev337";
  final String uploadPreset = "sunflower";

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedFile = result.files.first;
        _webImage = result.files.first.bytes;
      });
    } else {
      debugPrint('No image selected.');
    }
  }

  Future<void> _uploadImageToCloudinary() async {
    if (_pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request =
          http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                _pickedFile!.bytes!,
                filename: _pickedFile!.name,
              ),
            );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        final imageUrl = data['secure_url'];

        await FirebaseFirestore.instance.collection('images').add({
          'image_url': imageUrl,
          'uploaded_at': Timestamp.now(),
        });

        debugPrint('Upload successful! URL: $imageUrl');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );

        setState(() {
          _pickedFile = null;
          _webImage = null;
        });
      } else {
        debugPrint('Cloudinary upload failed: $resBody');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again later.')),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error during upload: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _cancelSelection() {
    setState(() {
      _pickedFile = null;
      _webImage = null;
      _isCanceling = false;
    });
  }

  void _deleteImage(String docId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this image?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('images')
            .doc(docId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully.')),
        );
      } catch (e) {
        debugPrint('Delete error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey.shade900,
        title: Text(
          'Sunflower',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.amber,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.amber),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Pick Image'),
                ),
                const SizedBox(width: 16),
                if (_pickedFile != null)
                  ElevatedButton(
                    onPressed: _uploadImageToCloudinary,
                    child:
                        _isUploading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('Upload'),
                  ),
                if (_pickedFile != null) const SizedBox(width: 16),
                if (_pickedFile != null)
                  ElevatedButton(
                    onPressed: _cancelSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_webImage != null)
              Center(
                child: Image.memory(
                  _webImage!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('images')
                        .orderBy('uploaded_at', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return const Center(child: Text('Error loading images'));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                    return const Center(child: Text('No images available.'));

                  return GridView.builder(
                    itemCount: snapshot.data!.docs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          (MediaQuery.of(context).size.width / 280).floor(),
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var imageUrl = doc['image_url'];
                      var uploadTime =
                          (doc['uploaded_at'] as Timestamp).toDate().toString();
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(imageUrl, fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteImage(doc.id),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black.withOpacity(0.5),
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Uploaded: $uploadTime',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}
