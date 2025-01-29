import 'dart:convert';
import 'package:chat_bubbles/bubbles/bubble_normal.dart';
import 'package:fbla_finance/pages/message.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
const ChatScreen({super.key});

@override
State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
TextEditingController controller = TextEditingController();
ScrollController scrollController = ScrollController();
List<Message> msgs = [];
bool isTyping = false;

void sendMsg() async {
	String text = controller.text;
	String apiKey = "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";
	controller.clear();
	try {
	if (text.isNotEmpty) {
		setState(() {
		msgs.insert(0, Message(true, text));
		isTyping = true;
		});
		scrollController.animateTo(0.0,
			duration: const Duration(seconds: 1), curve: Curves.easeOut);
		var response = await http.post(
			Uri.parse("https://api.openai.com/v1/chat/completions"),
			headers: {
			"Authorization": "Bearer $apiKey",
			"Content-Type": "application/json"
			},
			body: jsonEncode({
			"model": "gpt-3.5-turbo",
			"messages": [
				{"role": "user", "content": text}
			]
			}));
		if (response.statusCode == 200) {
		var json = jsonDecode(response.body);
		setState(() {
			isTyping = false;
			msgs.insert(
				0,
				Message(
					false,
					json["choices"][0]["message"]["content"]
						.toString()
						.trimLeft()));
		});
		scrollController.animateTo(0.0,
			duration: const Duration(seconds: 1), curve: Curves.easeOut);
		}
	}
	} on Exception {
	ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
		content: Text("Some error occurred, please try again!")));
	}
}

@override
Widget build(BuildContext context) {
	return Scaffold(
	appBar: AppBar(
		title: const Text("Fineas", style: TextStyle(fontSize: 40,fontWeight: FontWeight.bold,color: Colors.white),),
    centerTitle: true,
    backgroundColor: Colors.purple,
    leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.white), // Set the color to white
    onPressed: () {
      Navigator.pop(context); // Pop to the previous screen
    },
  ),
	),
	body: Column(
		children: [
		const SizedBox(
			height: 8,
		),
		Expanded(
			child: ListView.builder(
				controller: scrollController,
				itemCount: msgs.length,
				shrinkWrap: true,
				reverse: true,
				itemBuilder: (context, index) {
				return Padding(
					padding: const EdgeInsets.symmetric(vertical: 4),
					child: isTyping && index == 0
						? Column(
							children: [
								BubbleNormal(
								text: msgs[0].msg,
								isSender: true,
								color: Colors.purple,
								),
								const Padding(
								padding: EdgeInsets.only(left: 16, top: 4, bottom: 24),
								child: Align(
									alignment: Alignment.centerLeft,
									child: Text("Typing...")),
								)
							],
							)
						: BubbleNormal(
							text: msgs[index].msg,
							isSender: msgs[index].isSender,
							color: msgs[index].isSender
								? Colors.purple.shade200
								: Colors.grey.shade200,
							));
				}),
		),
		Row(
			children: [
			Expanded(
				child: Padding(
				padding: const EdgeInsets.all(8.0),
				child: Container(
					width: double.infinity,
					height: 40,
					decoration: BoxDecoration(
						color: Colors.grey[200],
						borderRadius: BorderRadius.circular(10)),
					child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 8),
					child: TextField(
						controller: controller,
						textCapitalization: TextCapitalization.sentences,
						onSubmitted: (value) {
						sendMsg();
						},
						textInputAction: TextInputAction.send,
						showCursor: true,
						decoration: const InputDecoration(
							border: InputBorder.none, hintText: "Enter text"),
					),
					),
				),
				),
			),
			InkWell(
				onTap: () {
				sendMsg();
				},
				child: Container(
				height: 40,
				width: 40,
				decoration: BoxDecoration(
					color: Colors.blue,
					borderRadius: BorderRadius.circular(30)),
				child: const Icon(
					Icons.send,
					color: Colors.white,
				),
				),
			),
			const SizedBox(
				width: 8,
			)
			],
		),
		],
	),
	);
}
}
