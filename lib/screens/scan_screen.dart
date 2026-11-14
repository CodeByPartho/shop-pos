import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera barcode scanner. On a scan, a known barcode adds the product
/// to the cart and this screen closes with the barcode; an unknown
/// barcode closes with the code so the caller can offer to add it as a
/// new product. A manual entry field is always available: cheap USB
/// scanners act like keyboards, and the web build may have no camera.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController _manualController = TextEditingController();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitCode(String code) {
    final cleaned = code.trim();
    if (cleaned.isEmpty || _handled) {
      return;
    }
    _handled = true;
    Navigator.of(context).pop(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final code = barcode.rawValue;
                  if (code != null && code.trim().isNotEmpty) {
                    _submitCode(code);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Camera is not available here. '
                    'Type the barcode below instead.\n'
                    '(${error.errorCode})',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Point the camera at a barcode, or type it below. '
                  'A USB scanner types the code here by itself.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) => _submitCode(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _submitCode(_manualController.text),
                      child: const Text('Find'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
