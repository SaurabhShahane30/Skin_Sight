
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Detection {
  final double x, y, width, height, confidence;
  final String label;
  final Color color;

  Detection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.label,
    required this.color,
  });
}

// Model configuration class
class ModelConfig {
  final String name;
  final String assetPath;
  final String displayName;
  final Color primaryColor;
  final IconData icon;
  final List<int> outputShape;
  final double defaultConfidenceThreshold;
  final Map<int, String> labelMap;
  final Map<int, Color> colorMap;
  final DetectionParser parser;

  ModelConfig({
    required this.name,
    required this.assetPath,
    required this.displayName,
    required this.primaryColor,
    required this.icon,
    required this.outputShape,
    required this.defaultConfidenceThreshold,
    required this.labelMap,
    required this.colorMap,
    required this.parser,
  });
}


// Abstract parser interface
abstract class DetectionParser {
  List<Detection> parseOutput(dynamic output, int origWidth, int origHeight, ModelConfig config);
}

// Acne detection parser
class AcneDetectionParser implements DetectionParser {
  @override
  List<Detection> parseOutput(dynamic output, int origWidth, int origHeight, ModelConfig config) {
    final detections = <Detection>[];
    final confidenceThreshold = config.defaultConfidenceThreshold;

    for (int i = 0; i < 8400; i++) {
      final classScore = output[0][4][i];

      if (classScore > confidenceThreshold) {
        final centerX = output[0][0][i];
        final centerY = output[0][1][i];
        final width = output[0][2][i];
        final height = output[0][3][i];

        final pixelCenterX = centerX * origWidth;
        final pixelCenterY = centerY * origHeight;
        final pixelWidth = width * origWidth;
        final pixelHeight = height * origHeight;

        final x = pixelCenterX - (pixelWidth / 2);
        final y = pixelCenterY - (pixelHeight / 2);

        detections.add(Detection(
          x: x,
          y: y,
          width: pixelWidth,
          height: pixelHeight,
          confidence: classScore,
          label: 'Acne',
          color: config.primaryColor,
        ));
      }
    }

    return detections;
  }
}

// Wrinkle detection parser
// Wrinkle detection parser
class WrinkleDetectionParser implements DetectionParser {
  @override
  List<Detection> parseOutput(dynamic output, int origWidth, int origHeight, ModelConfig config) {
    final detections = <Detection>[];
    print("=== WRINKLE PARSING DEBUG ===");

    List<double> thresholds = [0.01, 0.05, 0.1, 0.15, 0.25, 0.3, 0.5];

    for (double threshold in thresholds) {
      print("Trying threshold: $threshold");

      // Strategy A: YOLOv8 format parsing
      int foundWithStrategyA = 0;
      for (int i = 0; i < 8400; i++) {
        final objectConfidence = output[0][4][i];

        if (objectConfidence > threshold && objectConfidence <= 1.0) {
          int bestClass = -1;
          double bestClassScore = -1.0;

          for (int cls = 0; cls < config.labelMap.length; cls++) {
            if (5 + cls < config.outputShape[1]) {
              double classScore = output[0][5 + cls][i];
              if (classScore > bestClassScore) {
                bestClassScore = classScore;
                bestClass = cls;
              }
            }
          }

          double finalConfidence = objectConfidence * bestClassScore;

          if (finalConfidence > threshold && bestClass >= 0) {
            foundWithStrategyA++;

            final centerX = output[0][0][i];
            final centerY = output[0][1][i];
            final width = output[0][2][i];
            final height = output[0][3][i];

            double pixelCenterX = centerX;
            double pixelCenterY = centerY;
            double pixelWidth = width;
            double pixelHeight = height;

            if (centerX <= 1.0 && centerY <= 1.0 && width <= 1.0 && height <= 1.0) {
              pixelCenterX = centerX * origWidth;
              pixelCenterY = centerY * origHeight;
              pixelWidth = width * origWidth;
              pixelHeight = height * origHeight;
            }

            final x = pixelCenterX - (pixelWidth / 2);
            final y = pixelCenterY - (pixelHeight / 2);

            if (x >= 0 && y >= 0 && x + pixelWidth <= origWidth && y + pixelHeight <= origHeight &&
                pixelWidth > 5 && pixelHeight > 5) {
              detections.add(Detection(
                x: x,
                y: y,
                width: pixelWidth,
                height: pixelHeight,
                confidence: finalConfidence,
                label: config.labelMap[bestClass] ?? 'Wrinkle',
                color: config.colorMap[bestClass] ?? Colors.yellow,
              ));
            }
          }
        }
      }

      print("Strategy A found $foundWithStrategyA detections with threshold $threshold");
      if (foundWithStrategyA > 0) {
        print("Using Strategy A with threshold $threshold");
        break;
      }

      // Strategy B: Try different confidence row (row 19 instead of 4)
      int foundWithStrategyB = 0;
      for (int i = 0; i < 8400; i++) {
        final objectConfidence = output[0][19][i];

        if (objectConfidence > threshold && objectConfidence <= 1.0) {
          int classId = (output[0][4][i] * (config.labelMap.length - 1)).round().clamp(0, config.labelMap.length - 1);

          foundWithStrategyB++;

          final centerX = output[0][0][i];
          final centerY = output[0][1][i];
          final width = output[0][2][i];
          final height = output[0][3][i];

          double pixelCenterX = centerX;
          double pixelCenterY = centerY;
          double pixelWidth = width;
          double pixelHeight = height;

          if (centerX <= 1.0 && centerY <= 1.0 && width <= 1.0 && height <= 1.0) {
            pixelCenterX = centerX * origWidth;
            pixelCenterY = centerY * origHeight;
            pixelWidth = width * origWidth;
            pixelHeight = height * origHeight;
          }

          final x = pixelCenterX - (pixelWidth / 2);
          final y = pixelCenterY - (pixelHeight / 2);

          if (x >= 0 && y >= 0 && x + pixelWidth <= origWidth && y + pixelHeight <= origHeight &&
              pixelWidth > 5 && pixelHeight > 5) {
            detections.add(Detection(
              x: x,
              y: y,
              width: pixelWidth,
              height: pixelHeight,
              confidence: objectConfidence,
              label: config.labelMap[classId] ?? 'Wrinkle',
              color: config.colorMap[classId] ?? Colors.yellow,
            ));
          }
        }
      }

      print("Strategy B found $foundWithStrategyB detections with threshold $threshold");
      if (foundWithStrategyB > 0) {
        print("Using Strategy B with threshold $threshold");
        break;
      }

      detections.clear();
    }

    // Strategy C: Emergency fallback
    if (detections.isEmpty) {
      print("=== EMERGENCY DETECTION STRATEGY ===");

      for (int i = 0; i < 8400; i++) {
        for (int confRow = 4; confRow < config.outputShape[1]; confRow++) {
          final confidence = output[0][confRow][i];

          if (confidence > 0.001 && confidence <= 1.0) {
            final centerX = output[0][0][i];
            final centerY = output[0][1][i];
            final width = output[0][2][i];
            final height = output[0][3][i];

            bool coordsValid = false;
            double pixelCenterX = 0.0;
            double pixelCenterY = 0.0;
            double pixelWidth = 0.0;
            double pixelHeight = 0.0;

            if (centerX >= 0 && centerX <= 1 && centerY >= 0 && centerY <= 1 &&
                width > 0 && width <= 1 && height > 0 && height <= 1) {
              pixelCenterX = centerX * origWidth;
              pixelCenterY = centerY * origHeight;
              pixelWidth = width * origWidth;
              pixelHeight = height * origHeight;
              coordsValid = true;
            } else if (centerX >= 0 && centerX <= origWidth && centerY >= 0 && centerY <= origHeight &&
                width > 0 && width <= origWidth && height > 0 && height <= origHeight) {
              pixelCenterX = centerX;
              pixelCenterY = centerY;
              pixelWidth = width;
              pixelHeight = height;
              coordsValid = true;
            }

            if (coordsValid && pixelWidth > 10 && pixelHeight > 10) {
              final x = pixelCenterX - (pixelWidth / 2);
              final y = pixelCenterY - (pixelHeight / 2);

              if (x >= 0 && y >= 0 && x + pixelWidth <= origWidth && y + pixelHeight <= origHeight) {
                detections.add(Detection(
                  x: x,
                  y: y,
                  width: pixelWidth,
                  height: pixelHeight,
                  confidence: confidence,
                  label: 'Potential Wrinkle (Row $confRow)',
                  color: Colors.orange,
                ));

                print("Emergency detection found: conf=$confidence, row=$confRow, coords=(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)},${pixelWidth.toStringAsFixed(1)},${pixelHeight.toStringAsFixed(1)})");

                if (detections.length >= 5) break;
              }
            }
          }
        }
        if (detections.length >= 5) break;
      }
    }

    print("Final detections count: ${detections.length}");
    return detections;
  }
}
class GenericYOLOParser implements DetectionParser {
  @override
  List<Detection> parseOutput(dynamic output, int origWidth, int origHeight, ModelConfig config) {
    final detections = <Detection>[];
    final confidenceThreshold = config.defaultConfidenceThreshold;

    for (int i = 0; i < 8400; i++) {
      final conf = output[0][4][i];

      if (conf > confidenceThreshold) {
        final centerX = output[0][0][i];
        final centerY = output[0][1][i];
        final width = output[0][2][i];
        final height = output[0][3][i];

        double pixelCenterX = centerX <= 1.0 ? centerX * origWidth : centerX;
        double pixelCenterY = centerY <= 1.0 ? centerY * origHeight : centerY;
        double pixelWidth = width <= 1.0 ? width * origWidth : width;
        double pixelHeight = height <= 1.0 ? height * origHeight : height;

        final x = pixelCenterX - (pixelWidth / 2);
        final y = pixelCenterY - (pixelHeight / 2);

        if (_isValidBoundingBox(x, y, pixelWidth, pixelHeight, origWidth, origHeight)) {
          detections.add(Detection(
            x: x,
            y: y,
            width: pixelWidth,
            height: pixelHeight,
            confidence: conf,
            label: config.labelMap[0] ?? 'Unknown',
            color: config.colorMap[0] ?? config.primaryColor,
          ));
        }
      }
    }

    return detections;
  }
  bool _isValidBoundingBox(double x, double y, double width, double height, int imgWidth, int imgHeight) {
    return x >= 0 && y >= 0 &&
        x + width <= imgWidth && y + height <= imgHeight &&
        width > 5 && height > 5;
  }
}

class OilySkinDetectionParser implements DetectionParser {
  @override
  List<Detection> parseOutput(dynamic output, int origWidth, int origHeight, ModelConfig config) {
    final detections = <Detection>[];

    final predictions = output[0]; // e.g., [0.1, 0.6, 0.2, 0.1]
    int classIndex = 0;
    double maxConfidence = predictions[0];

    for (int i = 1; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        classIndex = i;
      }
    }

    detections.add(Detection(
      x: 0,
      y: 0,
      width: origWidth.toDouble(),
      height: origHeight.toDouble(),
      confidence: maxConfidence,
      label: config.labelMap[classIndex] ?? 'Unknown',
      color: config.colorMap[classIndex] ?? config.primaryColor,
    ));

    return detections;
  }
}

