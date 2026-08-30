import 'package:flutter/material.dart';

class FoodQuizPage extends StatefulWidget {
  final bool isTeamMode;
  const FoodQuizPage({super.key, this.isTeamMode = false});

  @override
  State<FoodQuizPage> createState() => _FoodQuizPageState();
}

class _FoodQuizPageState extends State<FoodQuizPage> {
  int currentQuestionIndex = 0;
  int score = 0;

  final List<Map<String, dynamic>> questions = [
    {
      "question": "What is ChiyaBreak's famous slogan?",
      "options": ["Eat Fresh", "TIME FOR A BREAK", "Have it your way", "I'm lovin' it"],
      "answer": 1
    },
    {
      "question": "Which of these is a signature ChiyaBreak snack?",
      "options": ["Big Mac", "Whopper", "Classic Chiya", "Crunchy Taco"],
      "answer": 2
    },
    {
      "question": "What type of drink is ChiyaBreak famous for?",
      "options": ["Crinkle Cut", "Waffle Fries", "Chiya", "Sweet Potato Fries"],
      "answer": 2
    },
    {
      "question": "ChiyaBreak was founded in which country?",
      "options": ["UK", "Canada", "Nepal", "Australia"],
      "answer": 2
    },
  ];

  void handleAnswer(int selectedIndex) {
    if (selectedIndex == questions[currentQuestionIndex]["answer"]) {
      setState(() {
        score += 10;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Correct! +10 points"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong answer!"), backgroundColor: Colors.red, duration: Duration(milliseconds: 500)),
      );
    }

    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Quiz Completed!"),
        content: Text("Your final score is $score."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to hub
            },
            child: const Text("Finish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentQuestionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5C00),
        elevation: 0,
        title: Text(widget.isTeamMode ? "Team Quiz" : "Food Trivia"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (currentQuestionIndex + 1) / questions.length,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFFFF5C00),
            ),
            const SizedBox(height: 32),
            Text(
              "Question ${currentQuestionIndex + 1}/${questions.length}",
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              currentQuestion["question"],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ...List.generate(
              currentQuestion["options"].length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => handleAnswer(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      currentQuestion["options"][index],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                "Current Score: $score",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
