from flask import Flask, jsonify, request
from flask_cors import CORS
import cv2
import numpy as np
import mediapipe as mp
from tensorflow.keras.models import load_model
from PIL import Image
import io

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web

# --- Model & MediaPipe Initialization ---
try:
    eye_model = load_model("eyes.h5")
    yawn_model = load_model("yawn_model.h5")
    print("Models loaded successfully.")
except Exception as e:
    print(f"Error loading models: {e}")
    exit(1)

# MediaPipe Face Mesh setup
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,  # Crucial for accurate eye landmarks
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# --- Landmark Indices (from MediaPipe documentation) ---
# These are the specific points on the 478-landmark model
LEFT_EYE_INDICES = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]
RIGHT_EYE_INDICES = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
MOUTH_OUTLINE_INDICES = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308]

# --- Helper Functions for Landmark Processing ---

def extract_feature_region(frame, landmarks, indices, w, h, padding=5):
    """
    Extracts a bounding box for a facial feature (eye or mouth) from landmarks.
    """
    if not landmarks:
        return None, None

    points = []
    for idx in indices:
        if idx < len(landmarks):
            x = int(landmarks[idx].x * w)
            y = int(landmarks[idx].y * h)
            points.append((x, y))

    if not points:
        return None, None

    # Calculate bounding box from the points
    x_coords = [p[0] for p in points]
    y_coords = [p[1] for p in points]
    
    x_min = max(min(x_coords) - padding, 0)
    y_min = max(min(y_coords) - padding, 0)
    x_max = min(max(x_coords) + padding, w)
    y_max = min(max(y_coords) + padding, h)

    # Ensure the box has a valid area
    if x_min >= x_max or y_min >= y_max:
        return None, None
        
    region = frame[y_min:y_max, x_min:x_max]
    
    if region.size == 0:
        return None, None

    # Return the cropped image and the bounding box coordinates
    return region, (x_min, y_min, x_max, y_max)


def calculate_mouth_aspect_ratio(landmarks, w, h):
    """Calculate mouth aspect ratio for yawn detection using specific landmarks."""
    try:
        # Vertical points
        p2 = landmarks[13]  # Top lip
        p6 = landmarks[14]  # Bottom lip
        # Horizontal points
        p1 = landmarks[61]  # Left corner
        p4 = landmarks[291] # Right corner

        # Calculate distances
        vertical_dist = np.linalg.norm(np.array([p2.x, p2.y]) - np.array([p6.x, p6.y]))
        horizontal_dist = np.linalg.norm(np.array([p1.x, p1.y]) - np.array([p4.x, p4.y]))
        
        if horizontal_dist == 0:
            return 0
        
        mar = vertical_dist / horizontal_dist
        return mar
    except Exception as e:
        print(f"Could not calculate MAR: {e}")
        return 0


@app.route('/process_frame', methods=['POST'])
def process_frame():
    try:
        if 'frame' not in request.files:
            return jsonify({"error": "No frame provided"}), 400

        file = request.files['frame']
        img = Image.open(file.stream).convert('RGB')
        frame = np.array(img)
        
        # The frame from Flutter is already RGB, no need to convert from BGR
        frame_resized = cv2.resize(frame, (640, 480))
        h, w, _ = frame_resized.shape

        # --- Primary Face and Landmark Detection using MediaPipe ---
        results = face_mesh.process(frame_resized)

        eye_status = "No Face"
        yawn_status = "No Face"
        eye_results = []
        mouth_result = None

        if results.multi_face_landmarks:
            # We only process the first face found
            face_landmarks = results.multi_face_landmarks[0].landmark
            
            # --- 1. Eye Processing ---
            left_eye_region, l_bbox = extract_feature_region(frame_resized, face_landmarks, LEFT_EYE_INDICES, w, h)
            right_eye_region, r_bbox = extract_feature_region(frame_resized, face_landmarks, RIGHT_EYE_INDICES, w, h)
            
            eye_statuses = []
            
            # Process left eye
            if left_eye_region is not None:
                eye_input = cv2.resize(left_eye_region, (224, 224)).astype(np.float32) / 255.0
                eye_input = np.expand_dims(eye_input, axis=0)
                prediction = eye_model.predict(eye_input, verbose=0)
                status = "Open Eyes" if prediction[0][0] > 0.5 else "Closed Eyes"
                eye_statuses.append(status)
                eye_results.append({"box": l_bbox, "status": status})

            # Process right eye
            if right_eye_region is not None:
                eye_input = cv2.resize(right_eye_region, (224, 224)).astype(np.float32) / 255.0
                eye_input = np.expand_dims(eye_input, axis=0)
                prediction = eye_model.predict(eye_input, verbose=0)
                status = "Open Eyes" if prediction[0][0] > 0.5 else "Closed Eyes"
                eye_statuses.append(status)
                eye_results.append({"box": r_bbox, "status": status})

            # Determine combined eye status
            if "Closed Eyes" in eye_statuses:
                eye_status = "Closed Eyes"
            elif "Open Eyes" in eye_statuses:
                eye_status = "Open Eyes"
            else:
                eye_status = "No Eyes Detected"

            # --- 2. Yawn Processing ---
            mouth_region, m_bbox = extract_feature_region(frame_resized, face_landmarks, MOUTH_OUTLINE_INDICES, w, h, padding=10)
            
            if mouth_region is not None:
                mouth_input = cv2.resize(mouth_region, (64, 64)).astype(np.float32) / 255.0
                mouth_input = np.expand_dims(mouth_input, axis=0)
                
                yawn_prediction = yawn_model.predict(mouth_input, verbose=0)
                confidence = float(yawn_prediction[0][0])
                
                # Use both model prediction and aspect ratio for robustness
                mar = calculate_mouth_aspect_ratio(face_landmarks, w, h)
                
                if confidence > 0.6 or mar > 0.5: # Thresholds might need tuning
                    yawn_status = "Yawning"
                else:
                    yawn_status = "Not Yawning"
                
                mouth_result = {
                    "box": m_bbox,
                    "status": yawn_status,
                    "confidence": confidence
                }
            else:
                yawn_status = "No Mouth Detected"

        return jsonify({
            "eye_status": eye_status,
            "eyes": eye_results,
            "yawn_status": yawn_status,
            "mouth": mouth_result,
        })

    except Exception as e:
        import traceback
        print(f"Error in /process_frame: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("Starting Drowsiness Detection Server with MediaPipe...")
    app.run(host='0.0.0.0', port=5000, debug=False) # Use debug=False for production