# BNS Section Recommendation System

This repository combines the **frontend** and **backend** of the BNS Section Recommendation System into a single project, preserving full commit history from both repositories.

---

## 📁 Folder Structure

```
BNS_Section_Recommendation_FullHistory/
├── frontend/  # Flutter frontend app
└── backend/   # Python backend API
```

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
$env:GROQ_API_KEY = [YOUR_GROQ_API_KEY_HERE]
```

2. **Run the backend server**:

```powershell
cd backend
python -m uvicorn app:app --host 0.0.0.0 --port 8001 --reload
```

The backend API will be available at:  
`http://localhost:8001`

---

## 🟢 Running the Frontend

1. Navigate to the frontend folder:

```bash
cd frontend
```

2. Install dependencies and run Flutter:

```bash
flutter pub get
flutter run
```

This will launch the frontend app (on emulator or connected device).

---

## 🔗 Connecting Frontend & Backend

- Make sure the backend server is running on **port 8001**.
- The frontend app communicates with the backend via HTTP API endpoints.

---

## 📓 Notes

- Ensure your **Groq API key** is valid before starting the backend.
- You can develop and test the frontend and backend independently.

---

## 📜 License

[MIT License](LICENSE) (or your preferred license)
