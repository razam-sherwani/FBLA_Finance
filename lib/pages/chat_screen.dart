import 'dart:convert';
import 'package:chat_bubbles/bubbles/bubble_normal.dart';
import 'package:fbla_finance/pages/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<Message> msgs = [];
  bool isTyping = false;

  final List<String> suggestedQuestions = [
    "How can I start saving money?",
    "What’s a good beginner investment?",
    "How do I create a budget?",
    "Tips for managing student loans?",
  ];

  void sendMsg([String? prefilledText]) async {
    String text = prefilledText ?? controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();

    setState(() {
      msgs.insert(0, Message(true, text));
      isTyping = true;
    });

    scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    try {
      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer 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",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are Fineas, a financial assistant. Provide financial advice, investment tips, and budgeting help. Make your responses short and concise being as helpful as possible in around 50 to 100 words."
            },
            {"role": "user", "content": text}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final reply = json["choices"][0]["message"]["content"]
            .toString()
            .trimLeft();

        setState(() {
          isTyping = false;
          msgs.insert(0, Message(false, reply));
        });
      } else {
        print("OpenAI error ${response.statusCode}: ${response.body}");
        setState(() => isTyping = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("OpenAI error ${response.statusCode}"),
        ));
      }
    } catch (e) {
      print("Caught error: $e");
      setState(() => isTyping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Try again.")),
      );
    }
  }

  Widget _buildSuggestedButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: suggestedQuestions.map((question) {
          return GestureDetector(
            onTap: () => sendMsg(question),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade300, width: 1.5),
              ),
              child: Text(
                question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          "Fineas",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF15314B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFFAFAFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "💼 Fineas - Your financial assistant",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Hi! I'm Fineas. Ask me about budgeting, saving, or investing.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
            _buildSuggestedButtons(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: msgs.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final msg = msgs[index];
                  final timestamp = TimeOfDay.now().format(context);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: msg.isSender
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        msg.isSender
                            ? BubbleNormal(
                                text: msg.msg,
                                isSender: true,
                                color: Colors.teal.shade100,
                                textStyle: const TextStyle(
                                    fontSize: 15, color: Colors.black87),
                                tail: true,
                              )
                            : Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg.msg,
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black87),
                                ),
                              ),
                        if (index % 3 == 0)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 16.0, top: 2.0),
                            child: Text(
                              timestamp,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        if (isTyping && index == 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 16, top: 6),
                            child: SpinKitThreeBounce(
                              color: Colors.teal,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: controller,
                          onSubmitted: (_) => sendMsg(),
                          decoration: const InputDecoration(
                            hintText: "Ask Fineas...",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => sendMsg(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
