import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'Model_Classes.dart';



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
      displayName: 'Acne Detection',
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
      assetPath: 'assets/wrinkles_model_v8s_float32.tflite',
      displayName: 'Wrinkle Detection',
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
      displayName: 'Dark Spots Detection',
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
      displayName: 'Skin Type Classification',
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
  }
}

// Updated Detection Screen
class DetectionScreen extends StatefulWidget {
  final String modelKey;

  DetectionScreen({required this.modelKey});

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  File? _selectedImage;
  File? _annotatedImage;
  List<Detection> _detections = [];
  bool _isProcessing = false;
  String _status = 'No image selected';

  ModelConfig? get _modelConfig => ModelManager.getModelConfig(widget.modelKey);

  String get _title => _modelConfig?.displayName ?? 'Detection';
  Color get _primaryColor => _modelConfig?.primaryColor ?? Colors.blue;

  Future<void> _pickImage() async {
    if (_isProcessing) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _annotatedImage = null;
        _detections = [];
        _status = 'Image selected. Tap "Analyze" to detect.';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_isProcessing) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _annotatedImage = null;
        _detections = [];
        _status = 'Image captured. Tap "Analyze" to detect.';
      });
    }
  }

  Future<void> _runDetection() async {
    if (_selectedImage == null || _isProcessing || _modelConfig == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Analyzing image...';
    });

    try {
      final detections = await _performDetection(_selectedImage!);
      final annotatedImage = await _createAnnotatedImage(_selectedImage!, detections);

      setState(() {
        _detections = detections;
        _annotatedImage = annotatedImage;
        _status = _getResultMessage(detections.length);
        _isProcessing = false;
      });
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
              (_) => List.generate(
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
    final detections = config.parser.parseOutput(output, origWidth, origHeight, config);

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

  List<Detection> _applyNMS(List<Detection> detections, {double iouThreshold = 0.4}) {
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

  Future<File> _createAnnotatedImage(File originalFile, List<Detection> detections) async {
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
        color: img.ColorRgb8(detection.color.red, detection.color.green, detection.color.blue),
        thickness: 35,
      );
    }

    // Save annotated image
    final annotatedPath = '${originalFile.parent.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png';
    final annotatedBytes = Uint8List.fromList(img.encodePng(image));
    return await File(annotatedPath).writeAsBytes(annotatedBytes);
  }

  String _getResultMessage(int count) {
    if (count == 0) {
      return 'No ${_modelConfig?.name ?? 'issues'} detected! Your skin looks great.';
    } else {
      final itemName = _modelConfig?.name ?? 'issue';
      final plural = count == 1 ? itemName : '${itemName}s';
      return 'Detected $count $plural';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Image display area
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
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

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Analyze button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedImage != null && !_isProcessing ? _runDetection : null,
                icon: _isProcessing
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.analytics),
                label: Text(_isProcessing ? 'Analyzing...' : 'Analyze Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Status and results
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_detections.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'Detection Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ..._detections.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final detection = entry.value;
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: detection.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '$index. ${detection.label} (${(detection.confidence * 100).toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model selection screen
class ModelSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final availableModels = ModelManager.getAvailableModelConfigs();

    return Scaffold(
      appBar: AppBar(
        title: Text('Skin Analysis'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Analysis Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select the type of skin analysis you want to perform',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: availableModels.length,
                itemBuilder: (context, index) {
                  final model = availableModels[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetectionScreen(modelKey: model.name),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              model.icon,
                              size: 48,
                              color: model.primaryColor,
                            ),
                            SizedBox(height: 12),
                            Text(
                              model.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
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