import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'Model_Classes.dart';

final supabase = Supabase.instance.client;



// Model registry and manager
class ModelManager {
  static final Map<String, Interpreter?> _interpreters = {};
  static final Map<String, ModelConfig> _modelConfigs = {};

  // Initialize with predefined models
  static void initializeModelConfigs() {
    // Acne model config
    _modelConfigs['acne'] = ModelConfig(
      name: 'acne',
      assetPath: 'assets/acne_float16.tflite',
      displayName: 'Acne',
      primaryColor: Colors.red,
      icon: Icons.warning,
      outputShape: [1, 5, 8400],
      defaultConfidenceThreshold: 0.15,
      labelMap: {0: 'Acne'},
      colorMap: {0: Colors.red},
      parser: AcneDetectionParser(),
    );

    // Wrinkle model config
    _modelConfigs['wrinkle'] = ModelConfig(
      name: 'wrinkle',
      assetPath: 'assets/wrinkles_model_v8s_float16.tflite',
      displayName: 'Wrinkle ',
      primaryColor: Colors.orange,
      icon: Icons.face,
      outputShape: [1, 20, 8400],
      defaultConfidenceThreshold: 0.1,
      labelMap: {
        0: 'Wrinkle',
      },
      colorMap: {
        0: Colors.green,
      },
      parser: WrinkleDetectionParser(),
    );

    // Example third model - Dark Spots
    _modelConfigs['dark_spots'] = ModelConfig(
      name: 'dark_spots',
      assetPath: 'assets/darkspot2_float16.tflite',
      displayName: 'Dark Spots',
      primaryColor: Colors.purple,
      icon: Icons.brightness_2,
      outputShape: [1, 5, 8400], // Assuming 3 classes: mild, moderate, severe
      defaultConfidenceThreshold: 0.2,
      labelMap: {
        0: 'Dark Spot',
      },
      colorMap: {
        0: Colors.pink,
      },
      parser: GenericYOLOParser(),
    );

    _modelConfigs['oily_skin']  = ModelConfig(
      name: 'oily_skin',
      assetPath: 'assets/oily_float16.tflite',
      displayName: 'Skin Type',
      primaryColor: Colors.blueGrey,
      icon: Icons.water_drop,
      outputShape: [9, 4], // 4 classes
      defaultConfidenceThreshold: 0.1,
      labelMap: {
        0: 'Dry',
        1: 'Normal',
        2: 'Oily',
        3: 'Sensitive',
      },
      colorMap: {
        0: Colors.brown,
        1: Colors.green,
        2: Colors.orange,
        3: Colors.pink,
      },
      parser: OilySkinDetectionParser(),
    );

  }

  // Add new model configuration
  static void addModelConfig(String modelKey, ModelConfig config) {
    _modelConfigs[modelKey] = config;
  }

  // Load all models
  static Future<void> loadAllModels() async {
    initializeModelConfigs();

    for (String modelKey in _modelConfigs.keys) {
      await loadModel(modelKey);
    }
  }

  // Load specific model
  static Future<void> loadModel(String modelKey) async {
    final config = _modelConfigs[modelKey];
    if (config == null) {
      print("❌ Model config not found for: $modelKey");
      return;
    }

    try {
      _interpreters[modelKey] = await Interpreter.fromAsset(config.assetPath);
      print("✅ ${config.displayName} loaded!");
    } catch (e) {
      print("❌ Failed to load ${config.displayName}: $e");
    }
  }

  static Interpreter? getModel(String modelKey) => _interpreters[modelKey];
  static ModelConfig? getModelConfig(String modelKey) => _modelConfigs[modelKey];
  static List<String> getAvailableModels() => _modelConfigs.keys.toList();
  static List<ModelConfig> getAvailableModelConfigs() => _modelConfigs.values.toList();

  static void dispose() {
    for (var interpreter in _interpreters.values) {
      interpreter?.close();
    }
    _interpreters.clear();
    _clearTempImages();
  }
}
void _clearTempImages() async {
  final tempDir = Directory.systemTemp;
  if (await tempDir.exists()) {
    final files = tempDir.listSync().whereType<File>().toList();
    for (var file in files) {
      if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}


// Updated Detection Screen
class DetectionScreen extends StatefulWidget {
  final String modelKey;
  final File imagePath; // 📸 image taken on Home Page
  final String iconAssetPath;

  DetectionScreen({
    required this.modelKey,
    required this.imagePath,
    required this.iconAssetPath,
  });

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}


class _DetectionScreenState extends State<DetectionScreen> {
  File? _selectedImage;
  File? _annotatedImage;
  List<Detection> _detections = [];
  bool _isProcessing = false;
  bool _detectionInProgress = true;
  String _status = 'No image selected';

  ModelConfig? get _modelConfig => ModelManager.getModelConfig(widget.modelKey);

  String get _title => _modelConfig?.displayName ?? 'Detection';


  Color get _primaryColor => _modelConfig?.primaryColor ?? Colors.blue;

  @override
  void initState() {
    super.initState();

    _selectedImage = widget.imagePath;
    _annotatedImage = null;
    _detections = [];
    _status = 'Preparing detection...';
    _detectionInProgress = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final model = ModelManager.getModel(widget.modelKey);

      if (model == null) {
        print("⚠️ Model not yet loaded: ${widget.modelKey}");
        setState(() {
          _status = 'Loading model...';
        });

        await ModelManager.loadModel(widget.modelKey);
      }

      setState(() {
        _status = 'Running analysis...';
      });

      await _runDetection();

      // ✅ Once detection is complete
      setState(() {
        _detectionInProgress = false;
      });
    });
  }


  // Future<void> _pickImage() async {
  //   if (_isProcessing) return;
  //
  //   final ImagePicker picker = ImagePicker();
  //   final XFile? image = await picker.pickImage(
  //     source: ImageSource.gallery,
  //     imageQuality: 80,
  //   );
  //
  //   if (image != null) {
  //     setState(() {
  //       _selectedImage = File(image.path);
  //       _annotatedImage = null;
  //       _detections = [];
  //       _status = 'Image selected. Tap "Analyze" to detect.';
  //     });
  //   }
  // }
  //
  //
  //
  // Future<void> _takePhoto() async {
  //   if (_isProcessing) return;
  //
  //   final ImagePicker picker = ImagePicker();
  //   final XFile? image = await picker.pickImage(
  //     source: ImageSource.camera,
  //     imageQuality: 80,
  //   );
  //
  //   if (image != null) {
  //     setState(() {
  //       _selectedImage = File(image.path);
  //       _annotatedImage = null;
  //       _detections = [];
  //       _status = 'Image captured. Tap "Analyze" to detect.';
  //     });
  //   }
  // }
  // Future<bool> _requestPermission() async {
  //   if (Platform.isAndroid) {
  //     final androidInfo = await DeviceInfoPlugin().androidInfo;
  //     final sdkInt = androidInfo.version.sdkInt;
  //
  //     if (sdkInt >= 33) {
  //       final photos = await Permission.photos.request(); // Android 13+
  //       return photos.isGranted;
  //     } else {
  //       final storage = await Permission.storage.request(); // Android <13
  //       return storage.isGranted;
  //     }
  //   }
  //   return true; // iOS or other platforms
  // }
  //
  // Future<void> _loadBluetoothImage() async {
  //   if (_isProcessing) return;
  //
  //   setState(() => _status = 'Requesting permissions...');
  //
  //   // ✅ Step 1: Check storage/media permissions
  //   final bool granted = await _requestPermission();
  //   if (!granted) {
  //     setState(() => _status = 'Permission denied. Please enable in app settings.');
  //     await openAppSettings();
  //     return;
  //   }
  //
  //   setState(() => _status = 'Scanning Bluetooth folder...');
  //
  //   // ✅ Step 2: Search Bluetooth and Download folders
  //   final possibleDirs = [
  //     Directory('/storage/emulated/0/Bluetooth/'),
  //     Directory('/storage/emulated/0/Download/'),
  //   ];
  //
  //   List<File> imageFiles = [];
  //
  //   for (var dir in possibleDirs) {
  //     if (await dir.exists()) {
  //       final files = dir
  //           .listSync()
  //           .whereType<File>()
  //           .where((file) =>
  //       file.path.toLowerCase().endsWith('.jpg') ||
  //           file.path.toLowerCase().endsWith('.jpeg') ||
  //           file.path.toLowerCase().endsWith('.png'))
  //           .toList();
  //       imageFiles.addAll(files);
  //     }
  //   }
  //
  //   if (imageFiles.isNotEmpty) {
  //     imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  //     final File latest = imageFiles.first;
  //
  //     setState(() {
  //       _selectedImage = latest;
  //       _annotatedImage = null;
  //       _detections = [];
  //       _status = 'Bluetooth image loaded. Tap "Analyze" to detect.';
  //     });
  //   } else {
  //     setState(() => _status = 'No image found in Bluetooth or Download folder.');
  //   }
  // }

  Future<void> _runDetection() async {
    if (_selectedImage == null || _isProcessing || _modelConfig == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Analyzing image...';
      _annotatedImage = null;
      _detectionInProgress = true;
    });

    try {
      final detections = await _performDetection(_selectedImage!);
      final annotatedImage = await _createAnnotatedImage(
          _selectedImage!, detections);

      setState(() {
        _detections = detections;
        _annotatedImage = annotatedImage;
        _status = _getResultMessage(detections.length);
        _isProcessing = false;
        _detectionInProgress = false;
      });
      final user = supabase.auth.currentUser;
      if (user != null && _selectedImage != null && _modelConfig != null) {
        final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImage!.path)}';
        final filePath = 'user_scans/$fileName';
        final fileBytes = await _selectedImage!.readAsBytes();

        try {
          // Upload to Supabase Storage (throws on error)
          await supabase.storage
              .from('scans')
              .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

          // Get Public URL
          final publicUrl = supabase.storage
              .from('scans')
              .getPublicUrl(filePath);

          // Insert into scan_history table
          final summary = _generateSkinSummary();
          final insertResponse = await supabase.from('scan_history').insert({
            'user_id': user.id,
            'model_key': widget.modelKey,
            'scan_type': _modelConfig?.displayName,  // or key
            'analysis': _getResultMessage(detections.length),
            'summary': _generateSkinSummary(),
            'image_url': publicUrl,
            'created_at': DateTime.now().toIso8601String(),
          }).select();


          if (insertResponse == null) {
            print("❌ No response from insert");
          } else {
            print("✅ Insert response: $insertResponse");
          }


          print("✅ Upload and DB insert successful");

        } catch (e) {
          print("❌ Upload failed: $e");
        }
      }

    } catch (e) {
      setState(() {
        _status = 'Error during analysis: $e';
        _isProcessing = false;
      });
    }
  }

  Future<List<Detection>> _performDetection(File imageFile) async {
    final interpreter = ModelManager.getModel(widget.modelKey);
    final config = _modelConfig;

    if (interpreter == null || config == null) {
      throw Exception('Model not loaded or config not found');
    }

    // Read and process image
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    final origWidth = originalImage.width;
    final origHeight = originalImage.height;
    print("Original image size: ${origWidth}x${origHeight}");

    // Resize image to model input size
    img.Image resized = img.copyResize(originalImage, width: 640, height: 640);
    final input = _imageToFloat32List(resized);

    // Create output tensor based on model config
    var output;
    if (config.outputShape.length == 3) {
      // Detection output (e.g. [1, 5, 8400])
      output = List.generate(
          config.outputShape[0],
              (_) =>
              List.generate(
                  config.outputShape[1],
                      (_) => List.filled(config.outputShape[2], 0.0)
              )
      );
    } else if (config.outputShape.length == 2) {
      // Classification output (e.g. [1, 4])
      output = List.generate(
          config.outputShape[0],
              (_) => List.filled(config.outputShape[1], 0.0)
      );
    } else {
      throw Exception("Unsupported output shape: ${config.outputShape}");
    }


    // Run the model
    interpreter.run(input, output);

    // Parse detections using the model's specific parser
    final detections = config.parser.parseOutput(
        output, origWidth, origHeight, config);

    // Apply Non-Maximum Suppression
    return _applyNMS(detections);
  }

  List<List<List<List<double>>>> _imageToFloat32List(img.Image image) {
    var input = List.generate(1, (_) =>
        List.generate(640, (_) =>
            List.generate(640, (_) =>
                List.filled(3, 0.0)
            )
        )
    );

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = image.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return input;
  }

  List<Detection> _applyNMS(List<Detection> detections,
      {double iouThreshold = 0.4}) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final finalDetections = <Detection>[];
    final suppressed = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      finalDetections.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        final iou = _calculateIoU(detections[i], detections[j]);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return finalDetections;
  }

  double _calculateIoU(Detection a, Detection b) {
    final x1 = math.max(a.x, b.x);
    final y1 = math.max(a.y, b.y);
    final x2 = math.min(a.x + a.width, b.x + b.width);
    final y2 = math.min(a.y + a.height, b.y + b.height);

    final interArea = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    final unionArea = a.width * a.height + b.width * b.height - interArea;

    return unionArea > 0 ? interArea / unionArea : 0;
  }

  Future<File?> _createAnnotatedImage(File originalFile,
      List<Detection> detections) async {
    final bytes = await originalFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image for annotation');
    }

    // Draw bounding boxes
    for (var detection in detections) {
      img.drawRect(
        image,
        x1: math.max(0, detection.x.toInt()),
        y1: math.max(0, detection.y.toInt()),
        x2: math.min(image.width, (detection.x + detection.width).toInt()),
        y2: math.min(image.height, (detection.y + detection.height).toInt()),
        color: img.ColorRgb8(
            detection.color.red, detection.color.green, detection.color.blue),
        thickness: 35,
      );
    }

    // ✅ Use unique filename
    final annotatedBytes = Uint8List.fromList(img.encodePng(image));
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    final tempPath = '${tempDir
        .path}/annotated_$timestamp.png'; // 👈 Unique name
    final tempFile = await File(tempPath).writeAsBytes(annotatedBytes);

    final fileSizeKB = await tempFile.length() / 1024;
    print("📏 Annotated image size: ${fileSizeKB.toStringAsFixed(2)} KB");

    return tempFile;
  }


  String _getResultMessage(int count) {
    if (count == 0) {
      return 'No ${_modelConfig?.name ??
          'issues'} detected! Your skin looks great.';
    } else {
      final itemName = _modelConfig?.name ?? 'issue';
      final plural = count == 1 ? itemName : '${itemName}s';
      return 'Detected $count $plural';
    }
  }

  String _getSkinTypeHeading() {
    if (_modelConfig?.name == 'oily_skin' && _detections.isNotEmpty) {
      final label = _detections.first.label;
      return 'Detected Skin Type: ${label[0].toUpperCase()}${label.substring(
          1)}';
    } else {
      return _getResultMessage(_detections.length);
    }
  }


  String _generateSkinSummary() {
    if (_detectionInProgress) {
      return 'Analyzing skin... Please wait.';
    }

    if (_detections.isEmpty) {
      return 'No skin issues detected. Your skin looks healthy and well-maintained. Keep up with your current skincare routine and stay hydrated!';
    }

    Map<String, int> counts = {};
    for (var d in _detections) {
      print('🔍 Detection label: "${d.label}"');
      final normalizedLabel = d.label.trim().toLowerCase(); // normalize casing
      counts[normalizedLabel] = (counts[normalizedLabel] ?? 0) + 1;
    }


    StringBuffer summary = StringBuffer();

    // Acne-specific example
    int acneCount = counts['acne'] ?? 0;
    if (acneCount > 0) {
      if (acneCount < 5) {
        summary.writeln(
            'Mild acne detected ($acneCount spots). Consider using a gentle cleanser and non-comedogenic moisturizer.');
      } else if (acneCount < 15) {
        summary.writeln(
            'Moderate acne detected ($acneCount spots). You may benefit from salicylic acid or benzoyl peroxide treatments.');
      } else {
        summary.writeln(
            'Severe acne detected ($acneCount spots). It’s recommended to consult a dermatologist for tailored treatment.');
      }
    }

    // Wrinkle-specific example
    int wrinkleCount = counts['wrinkle'] ?? 0;
    if (wrinkleCount > 0) {
      if (wrinkleCount < 5) {
        summary.writeln(
            'Mild wrinkles detected ($wrinkleCount lines). Early signs of aging are visible—use a daily moisturizer and apply SPF regularly to slow progression.');
      } else if (wrinkleCount < 15) {
        summary.writeln(
            'Moderate wrinkles detected ($wrinkleCount lines). Consider incorporating retinol or peptide-based creams into your nighttime routine.');
      } else {
        summary.writeln(
            'Severe wrinkles detected ($wrinkleCount lines). You may benefit from consulting a dermatologist for advanced treatments like chemical peels or microneedling.');
      }
    }


    // Dark spot-specific example
    int darkSpotCount = counts['dark spot'] ?? 0;
    if (darkSpotCount > 0) {
      if (darkSpotCount < 5) {
        summary.writeln(
            'Mild pigmentation detected ($darkSpotCount dark spot${darkSpotCount >
                1
                ? 's'
                : ''}). Consider using products with vitamin C or niacinamide to maintain an even tone.');
      } else if (darkSpotCount < 15) {
        summary.writeln(
            'Moderate dark spots detected ($darkSpotCount). Targeted treatments like AHAs, retinoids, or brightening serums can help reduce pigmentation over time.');
      } else {
        summary.writeln(
            'Severe dark spot presence detected ($darkSpotCount). You may benefit from consulting a dermatologist about advanced options like chemical peels or laser therapy.');
      }
    }

    Detection? oilySkinDetection;

    for (final d in _detections) {
      final label = d.label.trim().toLowerCase();
      if (['dry', 'normal', 'oily', 'sensitive'].contains(label)) {
        oilySkinDetection = d;
        break;
      }
    }


    if (oilySkinDetection != null) {
      final label = oilySkinDetection.label.trim().toLowerCase();
      final conf = (oilySkinDetection.confidence * 100).toStringAsFixed(1);

      switch (label) {
        case 'dry':
          summary.writeln(
              'Your skin is classified as Dry ($conf% confidence). Use hydrating moisturizers, avoid alcohol-based products, and apply a gentle cleanser.');
          break;
        case 'normal':
          summary.writeln(
              'Your skin is classified as Normal ($conf% confidence). Maintain your routine with mild products to keep it balanced and healthy.');
          break;
        case 'oily':
          summary.writeln(
              'Your skin is classified as Oily ($conf% confidence). Consider using non-comedogenic products, mattifying moisturizers, and cleansing twice daily.');
          break;
        case 'sensitive':
          summary.writeln(
              'Your skin is classified as Sensitive ($conf% confidence). Use fragrance-free, hypoallergenic products and avoid harsh exfoliants.');
          break;
      }
    }


    return summary.toString().trim();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFDF0D1), // Adjust based on your theme
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header (instead of AppBar)
              Row(
                children: [
                  Transform.rotate(
                    angle: 3.1416, // 180 degrees in radians (π)
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Image.asset(
                        'assets/images/arrow.png',
                        height: 28,
                        width: 28,
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Image.asset(
                    widget.iconAssetPath, // ✅ use from widget
                    height: 50,
                    width: 50,
                  ),
                  SizedBox(width: 50),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Image display area
              Container(
                margin: EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFBD5488).withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: _annotatedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _annotatedImage!,
                    fit: BoxFit.contain,
                  ),
                )
                    : _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                )
                    : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _modelConfig?.icon ?? Icons.image,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No image selected',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Spacer for future buttons if needed
              SizedBox(height: 16),

              // Results summary container
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.shade50,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _detectionInProgress
                    ? Column(
                  children: [
                    Text(
                      "Analyzing skin... Please wait.",
                      style:
                      TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 10),
                    CircularProgressIndicator(),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        _getSkinTypeHeading(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Divider(thickness: 1.2, color: Colors.grey.shade300),
                    SizedBox(height: 12),
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink.shade400,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _generateSkinSummary(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
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
}


// // Model selection screen
// class ModelSelectionScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final availableModels = ModelManager.getAvailableModelConfigs();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Skin Analysis'),
//         backgroundColor: Colors.teal,
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Choose Analysis Type',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey.shade800,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Select the type of skin analysis you want to perform',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//             SizedBox(height: 24),
//             Expanded(
//               child: GridView.builder(
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   crossAxisSpacing: 16,
//                   mainAxisSpacing: 16,
//                   childAspectRatio: 1.2,
//                 ),
//                 itemCount: availableModels.length,
//                 itemBuilder: (context, index) {
//                   final model = availableModels[index];
//                   return Card(
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: InkWell(
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => DetectionScreen(modelKey: model.name),
//                           ),
//                         );
//                       },
//                       borderRadius: BorderRadius.circular(12),
//                       child: Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               model.icon,
//                               size: 48,
//                               color: model.primaryColor,
//                             ),
//                             SizedBox(height: 12),
//                             Text(
//                               model.displayName,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.grey.shade800,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }