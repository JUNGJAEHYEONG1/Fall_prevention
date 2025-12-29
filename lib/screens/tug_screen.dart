import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'frt_screen.dart';
import 'rom_screen.dart';

enum TugState { notStarted, sitting, walking, turning, returning, finished }

class TUGScreen extends StatefulWidget {
  const TUGScreen({super.key});

  @override
  State<TUGScreen> createState() => _TUGScreenState();
}

class _TUGScreenState extends State<TUGScreen> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  List<Pose> _poses = [];

  TugState _currentState = TugState.notStarted;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00.00 초';
  String _riskLevel = '';

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

    if (_currentState == TugState.notStarted ||
        _currentState == TugState.finished) {
      _isProcessing = false;
      return; // 측정이 시작되지 않았으면 AI 분석 안 함
    }

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
          final pose = poses.first;
          if (_currentState == TugState.sitting) {
            // --- '일어섬' 감지 로직 (무릎 각도 170도 이상) ---
            final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
            final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
            final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
            final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
            final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
            final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

            if (leftHip != null &&
                rightHip != null &&
                leftKnee != null &&
                rightKnee != null &&
                leftAnkle != null &&
                rightAnkle != null) {
              final leftKneeAngle = _calculateAngle(
                leftHip,
                leftKnee,
                leftAnkle,
              );
              final rightKneeAngle = _calculateAngle(
                rightHip,
                rightKnee,
                rightAnkle,
              );

              print(
                'TUG - Sitting 상태: 일어섬 확인 중... L=${leftKneeAngle.toStringAsFixed(1)}°, R=${rightKneeAngle.toStringAsFixed(1)}°, 조건(> 170): ${leftKneeAngle > 170 && rightKneeAngle > 170}',
              );

              // 무릎이 거의 펴졌는지 (170도 이상) 확인하여 일어섬 감지
              if (leftKneeAngle > 170 && rightKneeAngle > 170) {
                setState(() {
                  _currentState = TugState.walking;
                  print(">>> 상태 변경: Sitting -> Walking (무릎 각도 기준 일어섬 감지)");
                });
              }
            }
          } else if (_currentState == TugState.walking ||
              _currentState == TugState.turning ||
              _currentState == TugState.returning) {
            // 사용자가 다시 앉았는지 감지하여 측정 종료
            final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
            final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
            final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
            final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
            final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
            final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

            // --- '앉음' 감지 로직 (무릎 각도 기준으로 수정) ---
            print('TUG - Walking/Returning 상태 진입 확인 중...');

            // 랜드마크 감지 여부 출력
            print(
              'TUG - 앉음 감지 랜드마크 확인: Hip=${leftHip != null && rightHip != null}, Knee=${leftKnee != null && rightKnee != null}, Ankle=${leftAnkle != null && rightAnkle != null}',
            );

            if (leftHip != null &&
                rightHip != null &&
                leftKnee != null &&
                rightKnee != null &&
                leftAnkle != null &&
                rightAnkle != null) {
              // 각도 계산
              final leftKneeAngle = _calculateAngle(
                leftHip,
                leftKnee,
                leftAnkle,
              );
              final rightKneeAngle = _calculateAngle(
                rightHip,
                rightKnee,
                rightAnkle,
              );

              print(
                'TUG - 각도 계산 완료 (앉음 확인용): L=${leftKneeAngle.toStringAsFixed(1)}°, R=${rightKneeAngle.toStringAsFixed(1)}',
              );

              // 무릎이 충분히 구부러졌는지 (예: 120도 미만) 확인하여 앉음 감지
              if (leftKneeAngle < 150 && rightKneeAngle < 150) {
                // 임계값 140도 (사용자 요청)
                print(
                  ">>> 상태 변경: Walking/Returning -> Finished (앉음 감지 - 무릎 각도 기준)",
                );
                // 측정 종료 setState
                setState(() {
                  _stopwatch.stop();
                  _timer?.cancel();
                  _currentState = TugState.finished;
                  final totalTimeInSeconds =
                      _stopwatch.elapsedMilliseconds / 1000;
                  if (totalTimeInSeconds >= 13.5) {
                    _riskLevel = '고위험';
                  } else if (totalTimeInSeconds >= 10) {
                    _riskLevel = '중간 위험';
                  } else {
                    _riskLevel = '저위험';
                  }
                });
              }
            } else {
              print('!!!!!!!! TUG - 앉음 감지 위한 필수 랜드마크 부족 !!!!!!!!!!');
            }
            // --- 무릎 각도 로직 끝 ---
          }
        }
      }
    } catch (e, stackTrace) {
      // print('오류 위치: $stackTrace'); // 스택 트레이스는 너무 길 수 있으니 일단 주석 처리
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    // 벡터 계산
    final vector1 = Offset(p1.x - p2.x, p1.y - p2.y);
    final vector2 = Offset(p3.x - p2.x, p3.y - p2.y);

    // 벡터 내적(dot product)을 이용한 각도 계산
    final dotProduct = vector1.dx * vector2.dx + vector1.dy * vector2.dy;
    final magnitude1 = vector1.distance;
    final magnitude2 = vector2.distance;

    double angleRad = 0.0;
    if (magnitude1 > 0 && magnitude2 > 0) {
      // 0으로 나누기 방지
      final cosTheta = dotProduct / (magnitude1 * magnitude2);
      // acos 결과는 0 ~ PI (0 ~ 180도) 범위
      angleRad = math.acos(cosTheta.clamp(-1.0, 1.0)); // clamp로 값 범위 보정
    }
    return angleRad * 180 / math.pi;
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

  void _startMeasurement() {
    if (_stopwatch.isRunning || _countdownTimer != null) {
      return;
    }

    setState(() {
      _elapsedTime = '00.00 초';
      _riskLevel = '';
      _countdown = 5;
      // _currentState는 아직 바꾸지 않음!
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        }
        if (_countdown == 0) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
          setState(() {
            _currentState = TugState.sitting; // ★★★ 실제 측정이 시작될 때 상태 변경 ★★★
          });
          _stopwatch.reset();
          _stopwatch.start();
          _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            setState(() {
              _elapsedTime =
                  '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} 초';
            });
          });
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('TUG 검사')),
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
                  onPressed: _startMeasurement,
                  child: Text(
                    (_currentState == TugState.notStarted ||
                            _currentState == TugState.finished)
                        ? '측정 시작'
                        : '측정 중...',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _elapsedTime,
                  style: const TextStyle(
                    fontSize: 24,
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
