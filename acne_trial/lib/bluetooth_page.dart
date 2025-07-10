import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class BluetoothPhotoReceiver extends StatefulWidget {
  const BluetoothPhotoReceiver({super.key});

  @override
  State<BluetoothPhotoReceiver> createState() => _BluetoothPhotoReceiverState();
}

class _BluetoothPhotoReceiverState extends State<BluetoothPhotoReceiver> {
  List<ScanResult> scannedDevices = [];
  bool isScanning = false;
  List<String> receivedImages = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _checkBluetoothState();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      _showPermissionDialog();
    }
  }

  Future<void> _checkBluetoothState() async {
    if (await FlutterBluePlus.isOn) {
      _startScan();
    } else {
      _showBluetoothDialog();
    }

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && !isScanning) {
        _startScan();
      } else if (state == BluetoothAdapterState.off) {
        setState(() {
          scannedDevices.clear();
          isScanning = false;
        });
      }
    });
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Required'),
        content: const Text('Please enable Bluetooth to receive photos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('Bluetooth, location, and storage permissions are required to receive photos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getDeviceName(ScanResult result) {
    final device = result.device;
    final advData = result.advertisementData;

    if (advData.localName.isNotEmpty) {
      return advData.localName;
    }
    if (device.advName.isNotEmpty) {
      return device.advName;
    }
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    return "Unknown Device";
  }

  void _startScan() {
    setState(() {
      scannedDevices.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        final device = result.device;
        if (!scannedDevices.any(
                (existing) => existing.device.remoteId == device.remoteId)) {
          setState(() {
            scannedDevices.add(result);
          });
        }
      }
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Photo Receiver'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceivedPhotosPage(images: receivedImages),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? _stopScan : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                const Text(
                  'Ready to receive photos via Bluetooth',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Received Photos: ${receivedImages.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Text(
              'Found ${scannedDevices.length} device(s)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: scannedDevices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isScanning
                        ? "Scanning for devices..."
                        : "No devices found.\nTap refresh to scan again.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: scannedDevices.length,
              itemBuilder: (context, index) {
                final result = scannedDevices[index];
                final device = result.device;
                final name = _getDeviceName(result);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${device.remoteId}'),
                        Text('RSSI: ${result.rssi} dBm'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        _stopScan();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoReceiveConnection(
                              scanResult: result,
                              onPhotoReceived: (imagePath) {
                                setState(() {
                                  receivedImages.add(imagePath);
                                });
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text("Connect"),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoReceiveConnection extends StatefulWidget {
  final ScanResult scanResult;
  final Function(String) onPhotoReceived;

  const PhotoReceiveConnection({
    super.key,
    required this.scanResult,
    required this.onPhotoReceived,
  });

  @override
  State<PhotoReceiveConnection> createState() => _PhotoReceiveConnectionState();
}

class _PhotoReceiveConnectionState extends State<PhotoReceiveConnection> {
  bool _connecting = true;
  String _status = 'Connecting...';
  BluetoothConnectionState? _deviceState;
  List<BluetoothService> _services = [];
  BluetoothDevice? get device => widget.scanResult.device;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _receivingPhoto = false;
  List<int> _imageData = [];

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _listenToDeviceState();
  }

  void _listenToDeviceState() {
    device?.connectionState.listen((state) {
      setState(() {
        _deviceState = state;
      });
    });
  }

  Future<void> _connectToDevice() async {
    try {
      await device?.connect(autoConnect: false);
      setState(() {
        _status = 'Connected! Waiting for photos...';
        _connecting = false;
      });
      _discoverServices();
    } catch (e) {
      setState(() {
        _status = "Connection failed: $e";
        _connecting = false;
      });
    }
  }

  Future<void> _discoverServices() async {
    try {
      final services = await device?.discoverServices();
      setState(() {
        _services = services ?? [];
      });
      _setupPhotoReceiving();
    } catch (e) {
      setState(() {
        _status = "Service discovery failed: $e";
      });
    }
  }

  void _setupPhotoReceiving() async {
    // Look for a suitable characteristic for file transfer
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          try {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              _handleReceivedData(value);
            });
            setState(() {
              _status = 'Ready to receive photos!';
            });
            return;
          } catch (e) {
            print('Failed to subscribe to characteristic: $e');
          }
        }
      }
    }

    // If no notify characteristic found, look for write characteristic
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          setState(() {
            _status = 'Connected - Device can send photos';
          });
          return;
        }
      }
    }

    setState(() {
      _status = 'Connected but no suitable transfer method found';
    });
  }

  void _handleReceivedData(List<int> data) {
    print('Received ${data.length} bytes');

    if (data.length >= 4 && !_receivingPhoto) {
      // Check if this is a photo header (first 4 bytes might be size)
      _totalBytes = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      if (_totalBytes > 0 && _totalBytes < 50000000) { // Reasonable image size limit
        setState(() {
          _receivingPhoto = true;
          _receivedBytes = 0;
          _imageData.clear();
          _status = 'Receiving photo...';
        });
        // Add remaining data after header
        if (data.length > 4) {
          _imageData.addAll(data.sublist(4));
          _receivedBytes = data.length - 4;
        }
      }
    } else if (_receivingPhoto) {
      _imageData.addAll(data);
      _receivedBytes += data.length;

      setState(() {
        _status = 'Receiving photo: ${_receivedBytes}/${_totalBytes} bytes';
      });

      if (_receivedBytes >= _totalBytes) {
        _processReceivedPhoto();
      }
    } else {
      // Try to detect image data by looking for JPEG/PNG headers
      if (data.length > 10) {
        // JPEG header: FF D8 FF
        // PNG header: 89 50 4E 47
        if ((data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) ||
            (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47)) {
          setState(() {
            _receivingPhoto = true;
            _imageData.clear();
            _imageData.addAll(data);
            _receivedBytes = data.length;
            _status = 'Receiving photo...';
          });
        }
      }
    }
  }

  Future<void> _processReceivedPhoto() async {
    try {
      // Convert bytes to Uint8List
      Uint8List imageBytes = Uint8List.fromList(_imageData);

      setState(() {
        _status = 'Photo received and sent to ML model!';
        _receivingPhoto = false;
        _receivedBytes = 0;
        _totalBytes = 0;
      });


    } catch (e) {
      setState(() {
        _status = 'Failed to process photo: $e';
        _receivingPhoto = false;
      });
    }
  }


  Future<void> _disconnectDevice() async {
    try {
      await device?.disconnect();
      setState(() {
        _status = 'Disconnected';
        _services.clear();
      });
    } catch (e) {
      setState(() {
        _status = "Disconnection failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = _getDeviceName(widget.scanResult);

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        backgroundColor: Colors.blue,
      ),
      body: _connecting
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to device...'),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'State: ${_deviceState?.toString().split('.').last ?? "Unknown"}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            if (_receivingPhoto) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receiving Photo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_totalBytes > 0)
                        LinearProgressIndicator(
                          value: _receivedBytes / _totalBytes,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${_receivedBytes} / ${_totalBytes} bytes',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Make sure the other device is ready to send photos\n'
                          '2. Photos will be automatically received and saved\n'
                          '3. Check the photo gallery to view received images\n'
                          '4. Keep this connection active while receiving',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _disconnectDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disconnect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviceName(ScanResult result) {
    final device = result.device;
    final advData = result.advertisementData;

    if (advData.localName.isNotEmpty) {
      return advData.localName;
    }
    if (device.advName.isNotEmpty) {
      return device.advName;
    }
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    return "Unknown Device";
  }

  @override
  void dispose() {
    device?.disconnect();
    super.dispose();
  }
}

class ReceivedPhotosPage extends StatelessWidget {
  final List<String> images;

  const ReceivedPhotosPage({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Received Photos (${images.length})'),
        backgroundColor: Colors.blue,
      ),
      body: images.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No photos received yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Connect to a device and receive photos via Bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imagePath = images[index];
          return Card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImage(imagePath: imagePath),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(imagePath)),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Photo ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Received Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}