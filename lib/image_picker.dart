import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'json_parser.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ImagePickerApp extends StatefulWidget {
  const ImagePickerApp({Key? key}) : super(key: key);

  @override
  State<ImagePickerApp> createState() => _ImagePickerAppState();
}

class _ImagePickerAppState extends State<ImagePickerApp> {
  File? _image; // Stores the selected image
  String _serverResponse = ''; // Stores the server response message
  bool _isLoading = false; // Tracks if an image is being uploaded

  /// Function to pick an image from the camera or gallery
  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) return; // User canceled image selection
      final imagePermanent = await _saveFilePermanently(pickedFile.path);

      setState(() {
        _image = imagePermanent;
      });
    } on PlatformException catch (e) {
      print('Failed to pick image: $e');
    }
  }

  /// Saves the picked image permanently in the app's storage
  Future<File> _saveFilePermanently(String imagePath) async {
    final name = basename(imagePath); // Extracts filename
    final directory = await getApplicationDocumentsDirectory();
    final image = File('${directory.path}/$name');

    return File(imagePath).copy(image.path); // Copies file to new location
  }

  /// Uploads the image along with location data to the server
  Future<void> _uploadImage(String title, File file) async {
    setState(() {
      _isLoading = true; // Shows loading indicator
      _serverResponse = ''; // Clears previous response
    });

    try {
      // Check if location services are enabled
      bool isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        setState(() {
          _serverResponse = 'Location services are disabled';
        });
        return;
      }

      // Check and request location permission if necessary
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _serverResponse = 'Location permission is permanently denied';
          });
          return;
        }
        if (permission == LocationPermission.denied) {
          setState(() {
            _serverResponse = 'Location permission is denied';
          });
          return;
        }
      }

      // Get the current location (latitude & longitude)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double latitude = position.latitude;
      double longitude = position.longitude;

      // Prepare image upload request
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("http://maiza.hawkinswinja.me/predict"),
      );

      request.fields['title'] = title;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.headers['Authorization'] = ""; // Add authentication if needed

      var picture = await http.MultipartFile.fromPath('image', file.path);
      request.files.add(picture);

      // Send request and handle response
      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var result = String.fromCharCodes(responseData);

      // Parse JSON response
      try {
        final parsedData =
            JsonParser.fromJson(jsonDecode(result)); // Ensure valid JSON
        setState(() {
          _serverResponse = "Recommendation: ${parsedData.recommendations}\n"
              "Disease: ${parsedData.disease}\n"
              "Description: ${parsedData.description}";
        });
      } catch (jsonError) {
        setState(() {
          _serverResponse = 'Failed to parse response: $jsonError';
        });
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Error uploading image: $e';
      });
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick an Image'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _image != null
                  ? Image.file(
                      _image!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : Image.asset('assets/p1.png'), // Default image placeholder
              const SizedBox(height: 20),

              // Buttons to pick an image
              CustomButton(
                title: 'Pick From Gallery',
                icon: Icons.image_outlined,
                onClick: () => _getImage(ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              CustomButton(
                title: 'Pick From Camera',
                icon: Icons.camera_alt_outlined,
                onClick: () => _getImage(ImageSource.camera),
              ),

              const SizedBox(height: 30),

              // Upload button with loading indicator
              GestureDetector(
                onTap: () {
                  if (_image != null) {
                    _uploadImage('image', _image!);
                  } else {
                    setState(() {
                      _serverResponse = 'Please pick an image first';
                    });
                  }
                },
                child: Container(
                  height: 55,
                  width: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 35, 178, 135),
                        Color(0xff281537),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Upload & Get Results',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Displays response from server
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _serverResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom button widget for picking an image
class CustomButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClick;

  const CustomButton({
    required this.title,
    required this.icon,
    required this.onClick,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue, // Sets button color
        ),
        onPressed: onClick,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
      ),
    );
  }
}
