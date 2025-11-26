# BNS Section Recommendation System

This repository combines the **frontend** and **backend** of the BNS Section Recommendation System into a single project, preserving full commit history from both repositories.

---

## 📁 Folder Structure



---

## ⚡ Requirements

- **Backend:** Python 3.9+  
- **Frontend:** Flutter 3+  
- **Backend Dependencies:** Listed in `backend/requirements.txt`  
- **Flutter Dependencies:** Listed in `frontend/pubspec.yaml`

---

## 🟢 Running the Backend

1. **Set your Groq API key** (PowerShell example):

```powershell
$env:GROQ_API_KEY = [YOUR_GROQ_API_KEY]

2. Run the backend server
Navigate to the backend folder and start the server:

PowerShell

cd backend
python -m uvicorn app:app --host 0.0.0.0 --port 8001 --reload
The backend API will be available at:

http://localhost:8001

📱 Running the Frontend
1. Navigate to the frontend folder
Bash

cd frontend
2. Run Flutter normally
Bash

flutter pub get
flutter run
This will launch the frontend app (on emulator or connected device).

🔗 Connecting Frontend & Backend
Make sure the backend server is running on port 8001.

The frontend app is configured to communicate with the backend via HTTP API endpoints at this port.

🛠 Convenience Scripts (Optional)
To save time, you can create a run_all.ps1 file in the root directory to launch both simultaneously:

PowerShell

# run_all.ps1
Start-Process powershell -ArgumentList "cd backend; `$env:GROQ_API_KEY='YOUR_KEY_HERE'; python -m uvicorn app:app --host 0.0.0.0 --port 8001 --reload"
Start-Process powershell -ArgumentList "cd frontend; flutter run"
📝 Notes
Ensure your Groq API key is valid before starting the backend.

You can develop and test the frontend and backend independently.
