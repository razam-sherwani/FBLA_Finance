import 'package:flutter/material.dart';

class AdvancedChatbot extends StatefulWidget {
  @override
  _AdvancedChatbotState createState() => _AdvancedChatbotState();
}

class _AdvancedChatbotState extends State<AdvancedChatbot> {
  final TextEditingController _textController = TextEditingController();
  final List<String> _chatMessages = [];

  final Map<String, String> responses = {
    "login": "To get started, please login or signup first. If you have issues with logging in or signing up, please don't hesitate to ask! We have a Forgot Password button if you face any issues with your password. Once logged in, you can explore the application, display and share your portfolio, and much more!",
    "signup": "To get started, please login or signup first. If you have issues with logging in or signing up, please don't hesitate to ask! We have a Forgot Password button if you face any issues with your password. Once logged in, you can explore the application, display and share your portfolio, and much more.",
    "how does this app work": "To get started, please login or signup first. Once logged in, you can explore the application, display and share your portfolio, and much more. If you have any other questions, please don't hesitate to ask!",
    "how do I upload my transcript": "You can upload your transcripts and display your grades in Scholar Sphere. Simply navigate to the upload section and follow the instructions.",
    "grades": "You can upload your transcripts and display your grades (like GPA) within the app. Simply navigate to the upload section and follow the instructions.",
    "gpa": "You can upload your transcripts and display your grades (like GPA) within the app. Simply navigate to the upload section and follow the instructions.",
    "how can I add awards": "To add awards in Scholar Sphere, simply navigate over to the Home Page and click on the button Awards. Then, click the + button to add awards. You can delete your awards as necessary as well. If you have any other questions, please don't hesitate to ask!",
    "clubs": "You can showcase your personalized awards, clubs, and extracurricular activities in your portfolio. Head over to the portfolio section to add these details.",
    "extracurriculars": "You can showcase your personalized awards, clubs, and extracurricular activities in your portfolio. Head over to the portfolio section to add these details.",
    "forgot password": "If you've forgotten your password, click on the 'Forgot Password' button on the login page to reset it.",
    "share portfolio": "You can share your portfolio with others and post it on social media. Additionally, you can save your portfolio as a specific file type.",
    "social media": "You can share your portfolio with others and post it on social media. Additionally, you can save your portfolio as a specific file type.",
    "save file": "You can share your portfolio with others and post it on social media. Additionally, you can save your portfolio as a specific file type.",
    "welcome screen": "Our app features a welcome screen, a to-do list, a home page, and a settings page to help you manage and customize your experience.",
    "to do list": "Our app features a welcome screen, a to-do list, a home page, and a settings page to help you manage and customize your experience.",
    "home page": "Our app features a welcome screen, a to-do list, a home page, and a settings page to help you manage and customize your experience.",
    "settings": "Our app features a welcome screen, a to-do list, a home page, and a settings page to help you manage and customize your experience.",
    "how does app work": "Our app allows you to create and manage your high school portfolio. You can upload your transcripts, display your grades, showcase your awards and extracurricular activities, and share your portfolio with others. Explore the app to discover more features!",
    "app functionality": "Our app allows you to create and manage your high school portfolio. You can upload your transcripts, display your grades, showcase your awards and extracurricular activities, and share your portfolio with others. Explore the app to discover more features!",
    "features": "Our app allows you to create and manage your high school portfolio. You can upload your transcripts, display your grades, showcase your awards and extracurricular activities, and share your portfolio with others. Explore the app to discover more features!",
    "what can this app do": "This app helps you manage and showcase your high school portfolio. You can upload and display your grades, achievements, and extracurricular activities, share your portfolio on social media, and customize your profile with various features.",
    "how to reset password": "If you forgot your password, you can reset it by clicking on the 'Forgot Password' button on the login page and following the instructions.",
    "forgot my password": "If you forgot your password, you can reset it by clicking on the 'Forgot Password' button on the login page and following the instructions.",
    "customize my profile": "To customize your profile, go to the settings page where you can update your personal information, change your profile picture, and adjust other preferences.",
    "profile settings": "To customize your profile, go to the settings page where you can update your personal information, change your profile picture, and adjust other preferences."
  };

  void _handleSubmitted(String message) {
    setState(() {
      _chatMessages.add("User: $message");
      String response = responses[message.toLowerCase().trim()] ?? "I'm not sure how to respond to that. Please ask a question related to the high school portfolio app.";
      _chatMessages.add("Bot: $response");
    });
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatbot'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                bool isUserMessage = _chatMessages[index].startsWith("User: ");
                return Align(
                  alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                    padding: EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: isUserMessage ? Colors.orange : Colors.purple,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      _chatMessages[index].replaceFirst(isUserMessage ? "User: " : "Bot: ", ""),
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Enter a message',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                SizedBox(width: 8.0),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: () {
                    _handleSubmitted(_textController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
