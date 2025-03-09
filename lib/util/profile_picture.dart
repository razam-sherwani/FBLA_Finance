
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePicture extends StatefulWidget {
  final String userId;
  const ProfilePicture({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfilePicture> createState() => _ProfilePictureState();
}

class _ProfilePictureState extends State<ProfilePicture> {
  Uint8List? pickedImage;

  @override
  void initState() {
    getProfilePicture();
    super.initState();
  }
  @override
  void didUpdateWidget(ProfilePicture oldWidget) {
    if (oldWidget.userId != widget.userId) {
      getProfilePicture();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) { //Returns the user selected profile
    return GestureDetector(
      onTap: onProfileTapped, //Calls function to change profile picture
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(//Decoration widget
            color: Colors.grey,
            shape: BoxShape.circle,
            image: pickedImage!=null ? DecorationImage( //Display the user selected image, or a default icon
              fit: BoxFit.cover,
              image: Image.memory(
                pickedImage!,
                fit: BoxFit.cover,
              ).image,
            ) : null,
          ),
          child: pickedImage==null ? const Center(
            child:  Icon(
              Icons.person_rounded,
              color: Colors.black38,
              size: 35,
            ),
          ): null,
        ),
      ),
    );
  }

  Future<void> getProfilePicture() async{
    final storageRef = FirebaseStorage.instance.ref();
    final imageRef = storageRef.child(widget.userId+'.jpg');

    try{
      final imageBytes = await imageRef.getData();
      if(imageBytes==null) return;  
      setState(() {
        pickedImage = imageBytes;
      });
    }catch(e){
      print("No profile picture found");
    }
  }

  Future<void> onProfileTapped() async { //Async to allow for user to choose image
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);//Awaits for image to be picked
    if(image==null) return;//Returns if no image is selected
    final storageRef = FirebaseStorage.instance.ref();//Firebase reference
    final imageRef = storageRef.child(widget.userId+'.jpg');//Sets unique image id
    final imageBytes = await image.readAsBytes();//Data convert
    await imageRef.putData(imageBytes);//Uploads

    setState(() {
      pickedImage = imageBytes;//Resets the state of all pages
    });
  }
}