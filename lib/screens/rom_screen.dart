import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'frt_screen.dart';
import 'tug_screen.dart';

enum RiskLevel { low, medium, high }

class ROMScreen extends StatefulWidget {
  const ROMScreen({super.key});

  @override
  State<ROMScreen> createState() => _ROMScreenState();
}

class _ROMScreenState extends State<ROMScreen> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  List<Pose> _poses = [];

  double _ankleAngle = 0.0;
  String _riskLevel = '';
  RiskLevel _peakRiskLevel = RiskLevel.low;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.stream,
      ),
    );
    _peakRiskLevel = RiskLevel.low;
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController!.startImageStream((image) {
        _processImage(image);
      });
    } else {
      print('Camera permission denied');
    }
  }

  void _processImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return; // Skip processing if conversion failed
    }

    try {
      final stopwatch = Stopwatch()..start(); // 시간 측정 시작
      final poses = await _poseDetector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 3)); // 3초 타임아웃 추가
      stopwatch.stop(); // 시간 측정 종료
      if (mounted) {
        setState(() {
          _poses = poses;
        });

        if (poses.isNotEmpty) {
          _calculateAnkleAngle(poses.first);
        }
      }
    } catch (e, stackTrace) {
      // print('오류 위치: $stackTrace'); // 스택 트레이스는 너무 길 수 있으니 일단 주석 처리
    } finally {
      _isProcessing = false;
    }
  }

  void _calculateAnkleAngle(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftHeel = pose.landmarks[PoseLandmarkType.leftHeel];
    final leftFootIndex = pose.landmarks[PoseLandmarkType.leftFootIndex];

    print(
      'ROM - 랜드마크 감지: 무릎=${leftKnee != null}, 발목=${leftAnkle != null}, 발뒤꿈치=${leftHeel != null}, 발끝=${leftFootIndex != null}',
    );
    if (leftAnkle == null ||
        leftKnee == null ||
        leftHeel == null ||
        leftFootIndex == null) {
      print('!!!!!!!! ROM - 필수 랜드마크 중 하나 이상 감지 실패 !!!!!!!!!!');
      return;
    }

    // 벡터 계산
    final vectorKneeAnkle = Offset(
      leftAnkle.x - leftKnee.x,
      leftAnkle.y - leftKnee.y,
    );
    final vectorAnkleFoot = Offset(
      leftFootIndex.x - leftAnkle.x,
      leftFootIndex.y - leftAnkle.y,
    );

    // 벡터 내적(dot product)을 이용한 각도 계산
    final dotProduct =
        vectorKneeAnkle.dx * vectorAnkleFoot.dx +
        vectorKneeAnkle.dy * vectorAnkleFoot.dy;
    final magnitudeKneeAnkle = vectorKneeAnkle.distance;
    final magnitudeAnkleFoot = vectorAnkleFoot.distance;

    double angleRad = 0.0;
    if (magnitudeKneeAnkle > 0 && magnitudeAnkleFoot > 0) {
      // 0으로 나누기 방지
      final cosTheta = dotProduct / (magnitudeKneeAnkle * magnitudeAnkleFoot);
      // acos 결과는 0 ~ PI (0 ~ 180도) 범위
      angleRad = math.acos(cosTheta.clamp(-1.0, 1.0)); // clamp로 값 범위 보정
    }
    double angleDeg = angleRad * 180 / math.pi;
    print('ROM - 계산된 각도: ${angleDeg.toStringAsFixed(1)}°');

    // TODO: 계산된 각도(무릎-발목-발끝 사이각)를 실제 '배측굴곡' 각도로 변환하는 로직 추가 필요
    // 예를 들어, 90도를 빼거나 특정 기준 각도와의 차이를 계산해야 할 수 있음
    // 일단은 계산된 내각을 그대로 사용

    final double calculatedAngle = angleDeg;
    late RiskLevel currentRiskLevel;
    if (calculatedAngle < 5) {
      _riskLevel = '고위험';
      currentRiskLevel = RiskLevel.high;
    } else if (calculatedAngle < 10) {
      _riskLevel = '중간 위험';
      currentRiskLevel = RiskLevel.medium;
    } else {
      _riskLevel = '저위험';
      currentRiskLevel = RiskLevel.low;
    }

    setState(() {
      _ankleAngle = calculatedAngle; // 2. _ankleAngle에 계산된 각도 저장만 함
      if (currentRiskLevel.index > _peakRiskLevel.index) {
        _peakRiskLevel = currentRiskLevel;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // InputImageRotation rotation = rotationIntToImageRotation(_cameraController!.description.sensorOrientation);
    // As the rotation setting is not working properly for now, we manually set it
    // TODO: fix rotation based on sensor orientation
    InputImageRotation rotation =
        InputImageRotation.rotation270deg; // Assuming front camera rotation

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv_420_888) || // <-- YUV_420_888 허용 추가
        (defaultTargetPlatform == TargetPlatform.iOS &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }

    // compose InputImage
    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes), // 모든 plane 데이터 합치기
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: InputImageFormat.nv21, // <-- YUV 대신 NV21로 강제 지정!
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  String _getScreenName() {
    if (widget.runtimeType == FRTScreen) return 'FRT';
    if (widget.runtimeType == TUGScreen) return 'TUG';
    if (widget.runtimeType == ROMScreen) return 'ROM';
    return 'Unknown';
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('발목 관절가동범위 검사')),
      body: Stack(
        children: [
          // CameraPreview를 Stack 전체로 확장
          FittedBox(
            fit: BoxFit.cover, // 화면을 덮도록 설정
            child: SizedBox(
              // CameraController의 비율에 맞는 크기 지정
              width: _cameraController!.value.previewSize!.height, // 회전 고려
              height: _cameraController!.value.previewSize!.width, // 회전 고려
              child: CameraPreview(_cameraController!),
            ),
          ),
          // CustomPaint도 Stack 전체로 확장
          if (_poses.isNotEmpty)
            Positioned.fill(
              // CustomPaint는 Positioned.fill이 더 안정적일 수 있음
              child: CustomPaint(
                painter: PosePainter(
                  poses: _poses,
                  screenName: _getScreenName(),
                  imageSize: Size(
                    _cameraController!.value.previewSize!.height,
                    _cameraController!.value.previewSize!.width,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Column이 차지하는 공간을 최소화
              children: [
                Text(
                  '현재 각도: ${_ankleAngle.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
                Text(
                  '현재 위험도: $_riskLevel',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
                Text(
                  '최고 위험도: ${_peakRiskLevel.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final String screenName;

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.screenName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors
          .yellow // <-- 빨간색 대신 노란색으로 변경
      ..strokeWidth =
          5.0 // <-- 두껍게 변경
      ..style = PaintingStyle.fill; // <-- 선 대신 채우기로 변경

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // 화면과 이미지 비율 중 작은 쪽을 기준으로 최종 스케일 결정 (가운데 정렬 위해)
    final double scale = math.min(scaleX, scaleY);

    // 이미지 스케일링 후 화면 중앙에 오도록 오프셋 계산
    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        // 좌표 계산 (회전된 이미지 기준 -> 스케일링 -> 중앙 정렬 -> 좌우 반전)
        final double dx =
            size.width - (landmark.x * scale + offsetX); // 좌우 반전 포함
        final double dy = landmark.y * scale + offsetY;

        canvas.drawCircle(
          Offset(dx, dy),
          5.0, // 점 크기는 그대로 유지 (이전에 5.0으로 바꿈)
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.poses != poses;
}
