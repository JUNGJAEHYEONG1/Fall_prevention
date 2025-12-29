import 'package:flutter/material.dart';

final List<Map<String, dynamic>> _questions = [
  {
    'question': '1. 최근 12개월 내 낙상 경험이 있습니까? (※낙상: 넘어지거나 미끄러지는 경우 포함)',
    'options': [
      {'text': '없음', 'score': 0},
      {'text': '1회, 부상 없음', 'score': 1},
      {'text': '2회 이상, 부상 없음', 'score': 2},
      {'text': '1회 이상, 골절·외상 등 부상 있음', 'score': 3},
    ],
  },
  {
    'question': '2. 정기적으로 복용 중인 약물이 몇 가지입니까? (비타민 제외, 매일 복용 약만)',
    'options': [
      {'text': '0~3가지', 'score': 0},
      {'text': '4가지 이상', 'score': 1},
      {'text': '졸음, 어지럼증, 혈압저하 유발 약 포함', 'score': 2},
      {'text': '위 약 포함 + 총 4가지 이상', 'score': 3},
    ],
  },
  {
    'question': '3. 다음 건강 질환 중 진단받은 것이 있습니까? (개수)',
    'options': [
      {'text': '0~1개', 'score': 0},
      {'text': '2~3개', 'score': 1},
      {'text': '4~5개', 'score': 2},
      {'text': '6개 이상', 'score': 3},
    ],
  },
  {
    'question': '4. 감각 문제 (시력 또는 다리 감각 저하)를 느끼십니까?',
    'options': [
      {'text': '없음', 'score': 0},
      {'text': '시력 저하', 'score': 1},
      {'text': '다리 감각 저하', 'score': 1},
      {'text': '시력과 감각 모두 문제 있음', 'score': 2},
    ],
  },
  {
    'question': '5. 발 문제나 잘 맞지 않는 신발을 사용하십니까?',
    'options': [
      {'text': '없음', 'score': 0},
      {'text': '발톱, 굳은살, 발 통증 있음', 'score': 1},
      {'text': '헐거운 신발, 미끄러운 밑창', 'score': 1},
      {'text': '둘 다 있음', 'score': 2},
    ],
  },
  {
    'question': '6. 인지 기능: 기억력이나 판단력이 떨어진다고 느끼십니까?',
    'options': [
      {'text': '없음', 'score': 0},
      {'text': '가끔 혼동됨', 'score': 1},
      {'text': '자주 혼동되거나 방향 감각 상실', 'score': 2},
      {'text': '치매 진단 또는 자주 길 잃음', 'score': 3},
    ],
  },
  {
    'question': '7. 요실금 또는 배변 실수가 있습니까?',
    'options': [
      {'text': '전혀 없음', 'score': 0},
      {'text': '가끔 있음', 'score': 1},
      {'text': '자주 있음', 'score': 2},
      {'text': '주야간 모두 조절 어려움', 'score': 3},
    ],
  },
  {
    'question': '8. 식사 및 체중 변화',
    'options': [
      {'text': '잘 먹고 체중 변화 없음', 'score': 0},
      {'text': '입맛 저하, 체중 약간 감소', 'score': 1},
      {'text': '최근 6개월 내 5kg 이상 감소', 'score': 2},
      {'text': '식욕 저하 + 음주 과다', 'score': 3},
    ],
  },
  {
    'question': '9. 집안이나 주변 환경에 낙상 위험 요인이 있습니까?',
    'options': [
      {'text': '없음', 'score': 0},
      {'text': '약간 있음', 'score': 1},
      {'text': '여러 곳에 있음', 'score': 2},
      {'text': '매우 위험한 환경', 'score': 3},
    ],
  },
  {
    'question': '10. 스스로의 신체 능력을 어떻게 평가하십니까?',
    'options': [
      {'text': '능력을 정확히 알고 있음', 'score': 0},
      {'text': '다소 과소평가함', 'score': 1},
      {'text': '과신하는 경향', 'score': 2},
      {'text': '실제 능력과 차이가 큼', 'score': 3},
    ],
  },
  {
    'question': '11. 일상생활 수행 능력 (ADL/IADL)',
    'options': [
      {'text': '혼자서 문제없이 가능', 'score': 0},
      {'text': '일부 활동만 도움 필요', 'score': 1},
      {'text': '대부분 활동에서 도움 필요', 'score': 2},
      {'text': '거의 모든 활동 도움 필요', 'score': 3},
    ],
  },
  {
    'question': '12. 균형 상태: 다음 활동 중 불안정함을 느끼십니까?',
    'options': [
      {'text': '전혀 불안정하지 않음', 'score': 0},
      {'text': '약간 불안정함', 'score': 1},
      {'text': '자주 불안정함', 'score': 2},
      {'text': '매우 불안정, 낙상 경험 있음', 'score': 3},
    ],
  },
  {
    'question': '13. 보행/신체 활동',
    'options': [
      {'text': '실내외 모두 독립 보행', 'score': 0},
      {'text': '보행 보조기 사용', 'score': 1},
      {'text': '실외 이동 시 타인 도움 필요', 'score': 2},
      {'text': '대부분 시간 누움 또는 휠체어', 'score': 3},
    ],
  },
];

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _questions.length; i++) {
      _answers[i] = 0; // Initialize all answers with score 0
    }
  }

  void _calculateScore() {
    final totalScore = _answers.values.fold(0, (sum, score) => sum + score);
    String riskLevel;
    String recommendations;

    if (totalScore <= 5) {
      riskLevel = '저위험';
      recommendations = '현재 낙상 위험이 낮습니다. 지속적인 건강 관리를 권장합니다.';
    } else if (totalScore <= 18) {
      riskLevel = '중간위험';
      recommendations = '낙상 위험이 있습니다. 전문가 상담 및 예방 프로그램 참여를 고려해보세요.';
    } else {
      riskLevel = '고위험';
      recommendations = '낙상 고위험군입니다. 즉시 전문가의 진단과 중재가 필요합니다.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설문 결과'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('총점: $totalScore점'),
            const SizedBox(height: 8),
            Text('위험도: $riskLevel'),
            const SizedBox(height: 16),
            const Text('권장 사항:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(recommendations),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('낙상 위험도 설문조사')),
      body: ListView.builder(
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['question'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List<Widget>.from(
                    (question['options'] as List).map(
                      (option) => RadioListTile<int>(
                        title: Text(option['text']),
                        value: option['score'],
                        groupValue: _answers[index],
                        onChanged: (value) {
                          setState(() {
                            _answers[index] = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _calculateScore,
        label: const Text('결과 보기'),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
