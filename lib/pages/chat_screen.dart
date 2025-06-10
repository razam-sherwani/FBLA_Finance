import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../pages/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<Message> msgs = [
    Message(false, "Hi! I'm Fineas, your financial assistant. Ask me anything about budgeting, saving, or investing.")
  ];
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
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: suggestedQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final question = suggestedQuestions[index];
          return GestureDetector(
            onTap: () => sendMsg(question),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF15314B), width: 1.2),
              ),
              child: Text(
                question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF15314B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, String timestamp, bool showTime) {
    final isSender = msg.isSender;
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSender ? const Color.fromARGB(255, 0, 140, 255) : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isSender ? 18 : 0),
                bottomRight: Radius.circular(isSender ? 0 : 18),
              ),
            ),
            child: Text(
              msg.msg,
              style: TextStyle(
                color: isSender ? Colors.white : Colors.black,
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
          if (showTime)
            Padding(
              padding: EdgeInsets.only(
                left: isSender ? 0 : 18,
                right: isSender ? 18 : 0,
                bottom: 4,
              ),
              child: Text(
                timestamp,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        shadowColor: Colors.transparent,
        title: Text(
          "Fineas",
          style: GoogleFonts.barlow(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFb7e9ff),
        elevation: 0.5,
        leading: IconButton(
          iconSize: 30,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: msgs.length,
              reverse: true,
              itemBuilder: (context, index) {
                final msg = msgs[index];
                final timestamp = TimeOfDay.now().format(context);
                final showTime = index % 3 == 0;
                return Column(
                  crossAxisAlignment:
                      msg.isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _buildMessageBubble(msg, timestamp, showTime),
                    if (isTyping && index == 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 6),
                        child: SpinKitThreeBounce(
                          color: Colors.lightBlueAccent,
                          size: 18,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _buildSuggestedButtons(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color.fromARGB(255, 165, 165, 165),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => sendMsg(),
                      decoration: InputDecoration(
                        hintText: "Ask Fineas...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: sendMsg,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromARGB(255, 0, 140, 255),
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white),
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
