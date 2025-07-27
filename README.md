# 😴 Drowsiness Detection

A Drowsiness Detection Website using Deep Learning, developed as part of an internship at Richinnovations, in collaboration with my teammate Subin Raj.
This web-based system detects signs of driver drowsiness like closed eyes and yawning in real-time, using webcam input and computer vision techniques.

## 🔍 Features
👁️ Eye State Detection using a deep learning model (TensorFlow)
😮 Yawn Detection using Mediapipe facial landmarks
🎥 Real-time webcam input handled by a Flask backend
🌐 Flutter Web frontend for user interface

## TechStack
- **Frontend:** Flutter Web  
- **Backend:** Python, Flask  
- **ML Tools:** TensorFlow, OpenCV, Mediapipe

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Praakaassh/drowsiness.git
cd drowsiness
```
### 2. Run the Flask Server
Make sure you have **Python 3** installed. If you encounter any errors related to missing libraries (like `flask`, `opencv-python`, `tensorflow`, or `mediapipe` etc), you can install them using:

```bash
pip install flask opencv-python tensorflow mediapipe
```
### 3. Run the Flutter Web App
Make sure you have **Flutter** installed and set up for web development.
```bash
flutter pub get
flutter run -d chrome
```


