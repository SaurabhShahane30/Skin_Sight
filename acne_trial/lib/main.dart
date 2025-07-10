import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:acne_trial/Both_detection.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:acne_trial/Both_detection.dart';

import 'bluetooth_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Skin Analysis Suite',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _loadingStatus = 'Initializing AI models...';
  late AnimationController _animationController;

  // Bluetooth related variables
  BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;
  bool _isBluetoothConnected = false;
  String _targetDeviceName =
      "Aarya's A23"; // Replace with your specific device name
  String _targetDeviceAddress =
      "D0:39:FA:9C:62:E3"; // Replace with your device MAC address
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  String? _receivedImagePath;
  bool _isReceivingImage = false;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  // Add these new variables for automatic image detection
  DateTime? _connectionTime;
  Timer? _imageMonitorTimer;
  String? _lastProcessedImagePath;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _initializeModels();
    _initializeBluetooth();
  }

  Future<void> _initializeModels() async {
    try {
      setState(() {
        _loadingStatus = 'Loading AI models...';
      });

      // Initialize and load all models
      await ModelManager.loadAllModels();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadingStatus = 'Error loading models: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeBluetooth() async {
    // Get current Bluetooth state
    _bluetoothState = await FlutterBluePlus.adapterState.first;

    // Listen for Bluetooth state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((
      BluetoothAdapterState state,
    ) {
      setState(() {
        _bluetoothState = state;
      });
    });

    // Check if already connected to target device
    _checkTargetDeviceConnection();
  }

  Future<void> _checkTargetDeviceConnection() async {
    try {
      // Check if device is already connected
      List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;

      for (BluetoothDevice device in connectedDevices) {
        if (device.platformName == _targetDeviceName ||
            device.remoteId.toString() == _targetDeviceAddress) {
          setState(() {
            _isBluetoothConnected = true;
            _connectedDevice = device;
          });
          _onBluetoothConnected(); // Record connection time
          _setupCharacteristics();
          break;
        }
      }
    } catch (e) {
      print('Error checking device connection: $e');
    }
  }

  Future<void> _connectToDevice() async {
    // Check Bluetooth permissions
    bool permissionsGranted = await _requestPermission();

    if (!permissionsGranted) {
      _showPermissionDeniedDialog();
      return;
    }

    if (_bluetoothState != BluetoothAdapterState.on) {
      _showBluetoothSettingsDialog();
      return;
    }

    // Start scanning for devices
    await _scanAndConnect();
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final photos = await Permission.photos.request(); // Android 13+
        return photos.isGranted;
      } else {
        final storage = await Permission.storage.request(); // Android <13
        return storage.isGranted;
      }
    }
    return true; // iOS or other platforms
  }

  Future<void> _scanAndConnect() async {
    try {
      // Start scanning
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));

      // Listen for scan results
      StreamSubscription<List<ScanResult>> scanSubscription = FlutterBluePlus
          .scanResults
          .listen((results) async {
            for (ScanResult result in results) {
              BluetoothDevice device = result.device;

              if (device.platformName == _targetDeviceName ||
                  device.remoteId.toString() == _targetDeviceAddress) {
                // Stop scanning
                await FlutterBluePlus.stopScan();

                // Connect to device
                await _connectToBluetoothDevice(device);
                break;
              }
            }
          });

      // Stop scanning after timeout
      Future.delayed(Duration(milliseconds: 2000), () async {
        await FlutterBluePlus.stopScan();
        scanSubscription.cancel();

        if (!_isBluetoothConnected) {
          _showDeviceNotFoundDialog();
        }
      });
    } catch (e) {
      print('Error during scan: $e');
      _showDeviceNotFoundDialog();
    }
  }

  Future<void> _connectToBluetoothDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      setState(() {
        _isBluetoothConnected = true;
        _connectedDevice = device;
      });

      // Record connection time and start monitoring
      _onBluetoothConnected();

      // Setup characteristics for communication
      await _setupCharacteristics();
    } catch (e) {
      print('Failed to connect to device: $e');
      _showDeviceNotFoundDialog();
    }
  }

  // New method to handle successful Bluetooth connection
  void _onBluetoothConnected() {
    _connectionTime = DateTime.now();
    print('Bluetooth connected at: $_connectionTime');

    // Start monitoring for new images
    _startImageMonitoring();
  }

  Future<void> _setupCharacteristics() async {
    if (_connectedDevice == null) return;

    try {
      // Discover services
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

      // Find the appropriate service and characteristics
      // You'll need to replace these UUIDs with your actual service/characteristic UUIDs
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.read ||
              characteristic.properties.notify) {
            _readCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            _characteristicSubscription = characteristic.lastValueStream.listen(
              (value) {
                _processReceivedData(value);
              },
            );
          }
          if (characteristic.properties.write) {
            _writeCharacteristic = characteristic;
          }
        }
      }
    } catch (e) {
      print('Error setting up characteristics: $e');
    }
  }

  void _processReceivedData(List<int> data) {
    if (data.isNotEmpty) {
      setState(() {
        _isReceivingImage = true;
      });

      // Process the received image data
      _processReceivedImage(data);
    }
  }

  // Modified to automatically detect latest image
  void _processReceivedImage(List<int> data) async {
    // The data parameter is not used anymore since we're detecting files automatically

    setState(() {
      _isReceivingImage = false;
    });

    // Automatically load the latest image from Downloads
    await _loadLatestImage();
  }

  // Start monitoring for new images in Downloads folder
  void _startImageMonitoring() {
    // Cancel any existing timer
    _imageMonitorTimer?.cancel();

    // Check for new images every 3 seconds
    _imageMonitorTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (_connectionTime != null && _isBluetoothConnected) {
        await _loadLatestImage();
      }
    });
  }

  // Load the latest image from Downloads folder
  Future<void> _loadLatestImage() async {
    try {
      String? latestImagePath = await _getLatestImageFromDownloads();

      if (latestImagePath != null &&
          latestImagePath != _lastProcessedImagePath) {
        setState(() {
          _receivedImagePath = latestImagePath;
          _lastProcessedImagePath = latestImagePath;
        });

        print('New image detected: $latestImagePath');

        // Optional: Process the image automatically
        // You can call your image processing function here
        // _processImageForAcneDetection(latestImagePath);
      }
    } catch (e) {
      print('Error loading latest image: $e');
    }
  }

  // Get the latest image from Downloads folder after connection time
  Future<String?> _getLatestImageFromDownloads() async {
    if (_connectionTime == null) {
      return null;
    }

    // Common download directories
    List<String> downloadPaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM/Camera',
    ];

    List<FileSystemEntity> allImages = [];

    // Search all possible download directories
    for (String dirPath in downloadPaths) {
      try {
        Directory dir = Directory(dirPath);
        if (await dir.exists()) {
          List<FileSystemEntity> files = await dir.list().toList();

          // Filter for image files
          List<FileSystemEntity> images =
              files.where((file) {
                String fileName = path.basename(file.path).toLowerCase();
                return fileName.endsWith('.jpg') ||
                    fileName.endsWith('.jpeg') ||
                    fileName.endsWith('.png') ||
                    fileName.endsWith('.gif') ||
                    fileName.endsWith('.bmp') ||
                    fileName.endsWith('.webp');
              }).toList();

          allImages.addAll(images);
        }
      } catch (e) {
        print('Error accessing directory $dirPath: $e');
      }
    }

    if (allImages.isEmpty) {
      return null;
    }

    // Filter images created after Bluetooth connection
    List<FileSystemEntity> recentImages = [];

    for (FileSystemEntity file in allImages) {
      try {
        FileStat stat = await file.stat();
        DateTime modificationTime = stat.modified;

        // Check if file was modified after Bluetooth connection
        if (modificationTime.isAfter(_connectionTime!)) {
          recentImages.add(file);
        }
      } catch (e) {
        print('Error getting file stats for ${file.path}: $e');
      }
    }

    if (recentImages.isEmpty) {
      return null;
    }

    // Sort by modification time (newest first)
    recentImages.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (e) {
        return 0;
      }
    });

    // Return the path of the most recent image
    return recentImages.first.path;
  }

  void _showBluetoothSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Bluetooth Required'),
          content: Text('Please enable Bluetooth to connect to your device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Note: FlutterBluePlus doesn't have requestEnable,
                // user needs to enable manually
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showDeviceNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Device Not Found'),
          content: Text(
            'Cannot find or connect to $_targetDeviceName. Please ensure the device is paired and in range.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close current screen
                final intent = AndroidIntent(
                  action: 'android.settings.BLUETOOTH_SETTINGS',
                );
                intent.launch();
              },

              child: Text('Go to Bluetooth Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text(
            'Bluetooth permissions are required to connect to your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _disconnectDevice() async {
    if (_connectedDevice != null) {
      await _characteristicSubscription?.cancel();
      await _connectedDevice!.disconnect();
    }

    // Stop image monitoring
    _imageMonitorTimer?.cancel();

    setState(() {
      _isBluetoothConnected = false;
      _connectedDevice = null;
      _readCharacteristic = null;
      _writeCharacteristic = null;
      _receivedImagePath = null;
      _connectionTime = null;
      _lastProcessedImagePath = null;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _adapterStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _imageMonitorTimer?.cancel(); // Cancel image monitoring timer
    _disconnectDevice();
    ModelManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(color: Color(0xfffff4d9)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * 3.14159,
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 80,
                        color: Color(0xFFD17A7A),
                      ),
                    );
                  },
                ),
                SizedBox(height: 30),
                Text(
                  'AI Skin Analysis',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4B7A),
                  ),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD17A7A)),
                ),
                SizedBox(height: 20),
                Text(
                  _loadingStatus,
                  style: TextStyle(fontSize: 16, color: Color(0xFF8B4B7A)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Color(0xfffff4d9)),
        child: SafeArea(
          child: Column(
            children: [
              // Header section
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8B4B7A),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              'Aarya Gharmalkar',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFFD17A7A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Color(0xFFD17A7A),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main content area
              // Main content area
              SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  // ✅ Make content scrollable
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================== 1. Connect a device ==================
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
                          child:
                              !_isBluetoothConnected
                                  ? GestureDetector(
                                    onTap: _connectToDevice,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Color(0xFFBD5488),
                                          width: 0.5,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.bluetooth,
                                            size: 30,
                                            color: Color(0xFFD17A7A),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Connect a device',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF8B4B7A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  : GestureDetector(
                                    onTap: _disconnectDevice,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Color(
                                            0xFF4CAF50,
                                          ), // Green border for connected
                                          width: 0.5,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.bluetooth_connected,
                                            size: 30,
                                            color: Color(
                                              0xFF4CAF50,
                                            ), // Green for connected
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Device connected',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF4CAF50),
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tap to disconnect',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                        ),

                        // ================== 2. Image receiving area ==================
                        if (_isBluetoothConnected) ...[
                          Container(
                            padding: EdgeInsets.only(left:12,right:12,top:20,bottom: 50),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 270,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFF5F5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Color(0xFFE0E0E0),
                                  width: 2,
                                ),
                              ),
                              child:
                                  _isReceivingImage
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFD17A7A),
                                                  ),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Receiving image...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF8B4B7A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : _receivedImagePath != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.file(
                                          File(_receivedImagePath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      )
                                      : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 50,
                                            color: Color(0xFFD17A7A),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            '1. Make sure the other device is ready to send photos.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8B4B7A),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '2. Photos will be automatically received and saved.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8B4B7A),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '3. Check the photo gallery to view received images.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8B4B7A),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ],
                        SizedBox(height: 20),
                        // ================== 3. Analyse your skin ==================
                        Text(
                          'Analyse your skin for',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B4B7A),
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.only(left: 20,right: 20,top: 20,bottom: 20),
                          margin: EdgeInsets.only(
                            bottom: 80,
                          ), // Leave space for nav bar
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.2,
                                shrinkWrap: true, // ✅ Prevent overflow
                                physics: NeverScrollableScrollPhysics(),
                                children: [
                                  _buildAnalysisOption(
                                    'Acne',
                                    Icons.face_outlined,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DetectionScreen(
                                              modelKey: 'acne',
                                            ),
                                      ),
                                    ),
                                  ),
                                  _buildAnalysisOption(
                                    'Dark spots',
                                    Icons.circle_outlined,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DetectionScreen(
                                              modelKey: 'dark_spots',
                                            ),
                                      ),
                                    ),
                                  ),
                                  _buildAnalysisOption(
                                    'Moisture',
                                    Icons.water_drop_outlined,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DetectionScreen(
                                              modelKey: 'oily_skin',
                                            ),
                                      ),
                                    ),
                                  ),
                                  _buildAnalysisOption(
                                    'Wrinkles',
                                    Icons.face_retouching_natural_outlined,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DetectionScreen(
                                              modelKey: 'wrinkle',
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom navigation
              Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home, 'Home', true),
                    _buildNavItem(Icons.settings, 'Settings', false),
                    _buildNavItem(Icons.history, 'History', false),
                    _buildNavItem(Icons.person, 'My Profile', false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: isActive ? Color(0xFFD17A7A) : Color(0xFFCCCCCC),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Color(0xFFD17A7A) : Color(0xFFCCCCCC),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisOption(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Color(0xFFD17A7A)),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B4B7A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
