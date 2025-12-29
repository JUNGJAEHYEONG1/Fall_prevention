import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'rom_screen.dart';
import 'tug_screen.dart';

class FRTScreen extends StatefulWidget {
  const FRTScreen({super.key});

  @override
  State<FRTScreen> createState() => _FRTScreenState();
}

class _FRTScreenState extends State<FRTScreen> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isMeasuring = false;
  bool _isUsingRightWrist = true;
  List<Pose> _poses = [];
  double _reachDistance = 0.0;
  double _startingWristX = 0.0;
  String _riskLevel = '';
  int _frameCounter = 0;
  int _countdown = 5;
  Timer? _countdownTimer;

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
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      // Using the front camera
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
      // Handle permission denial
      print('Camera permission denied');
    }
  }

  void _processImage(CameraImage image) async {
    if (_isProcessing) return;

    _frameCounter++;
    if (_frameCounter % 10 != 0) {
      // 5 프레임 중 1번만 처리 (숫자 조절 가능)
      // _isProcessing is already false, so we can just return.
      return;
    }

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

        if (_isMeasuring && poses.isNotEmpty) {
          final pose = poses.first;
          final wristLandmark = _isUsingRightWrist
              ? pose.landmarks[PoseLandmarkType.rightWrist]
              : pose.landmarks[PoseLandmarkType.leftWrist];

          if (wristLandmark != null) {
            // --- 어깨-엉덩이 거리 기반 픽셀-cm 비율 계산 ---
            double pixelToCmRatio = 0.05; // 기본/대체 값

            // 사용할 어깨 및 엉덩이 랜드마크 가져오기 (오른쪽/왼쪽 중 감지되는 쪽 사용)
            final shoulderLandmark =
                pose.landmarks[_isUsingRightWrist
                    ? PoseLandmarkType.rightShoulder
                    : PoseLandmarkType.leftShoulder];
            final hipLandmark =
                pose.landmarks[_isUsingRightWrist
                    ? PoseLandmarkType.rightHip
                    : PoseLandmarkType.leftHip];

            if (shoulderLandmark != null && hipLandmark != null) {
              // 어깨와 엉덩이 사이의 "세로" 픽셀 거리 계산
              final torsoLengthPx = (shoulderLandmark.y - hipLandmark.y).abs();

              if (torsoLengthPx > 0) {
                // 성인 평균 상체 길이(어깨-엉덩이)를 약 50cm로 가정 (값은 조정 필요)
                const avgTorsoLengthCm = 50.0;
                pixelToCmRatio = avgTorsoLengthCm / torsoLengthPx;
                print(
                  'FRT 보정: 어깨Y=${shoulderLandmark.y.toStringAsFixed(1)}, 엉덩이Y=${hipLandmark.y.toStringAsFixed(1)}, 세로픽셀=${torsoLengthPx.toStringAsFixed(1)}, 비율=${pixelToCmRatio.toStringAsFixed(3)}',
                ); // 디버깅 Print 추가
              } else {
                print('FRT 보정 실패: 어깨/엉덩이 세로 거리 0'); // 디버깅 Print 추가
              }
            } else {
              print('FRT 보정 실패: 어깨 또는 엉덩이 랜드마크 감지 안됨'); // 디버깅 Print 추가
            }
            // --- 비율 계산 끝 ---

            final currentPixelDistance = (wristLandmark.x - _startingWristX)
                .abs();
            final currentCmDistance = currentPixelDistance * pixelToCmRatio;

            if (currentCmDistance > _reachDistance) {
              setState(() {
                _reachDistance = currentCmDistance;
              });
            }
          }
        }
      }
    } catch (e, stackTrace) {
      // print('오류 위치: $stackTrace'); // 스택 트레이스는 너무 길 수 있으니 일단 주석 처리
    } finally {
      _isProcessing = false;
    }
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

  void _toggleMeasurement() {
    if (_isMeasuring || _countdownTimer != null) {
      // 측정 종료
      if (_isMeasuring) {
        setState(() {
          _isMeasuring = false;
          if (_reachDistance < 15) {
            _riskLevel = '고위험';
          } else if (_reachDistance >= 15 && _reachDistance <= 25) {
            _riskLevel = '중간 위험';
          } else {
            _riskLevel = '저위험';
          }
        });
      }
      return;
    }

    // 측정 시작 (카운트다운)
    setState(() {
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
        if (_countdown == 0) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
          // 실제 측정 시작
          if (_poses.isNotEmpty) {
            final pose = _poses.first;
            final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
            final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

            if (rightWrist != null) {
              setState(() {
                _isMeasuring = true;
                _reachDistance = 0.0;
                _riskLevel = '';
                _isUsingRightWrist = true;
                _startingWristX = rightWrist.x;
              });
            } else if (leftWrist != null) {
              setState(() {
                _isMeasuring = true;
                _reachDistance = 0.0;
                _riskLevel = '';
                _isUsingRightWrist = false;
                _startingWristX = leftWrist.x;
              });
            } else {
              print('손목이 감지되지 않아 측정을 시작할 수 없습니다.');
            }
          }
        }
      });
    });
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
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
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
            children: [
              if (_countdownTimer != null && _countdown > 0)
                Text(
                  '$_countdown',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 10.0, color: Colors.black)],
                  ),
                ),
              ElevatedButton(
                onPressed: _toggleMeasurement,
                child: Text(
                  (_isMeasuring || _countdownTimer != null) ? '측정 종료' : '측정 시작',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '측정 거리: ${_reachDistance.toStringAsFixed(2)} cm',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
              Text(
                '위험도: $_riskLevel',
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
