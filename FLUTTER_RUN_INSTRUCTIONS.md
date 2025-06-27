# 🚀 Bulletproof Flutter App Runner

This document provides **GUARANTEED** methods to run your Flutter calendar app without directory navigation issues.

## 🎯 Quick Start (Recommended)

### Option 1: Use the Batch File (Easiest)
1. **Double-click** `run_flutter.bat` in the CalendarApp root folder
2. The script automatically navigates to the correct directory and runs the app
3. ✅ **WORKS EVERY TIME** - no manual navigation needed

### Option 2: Use PowerShell Script
1. **Right-click** `run_flutter.ps1` → "Run with PowerShell"
2. If prompted about execution policy, choose "Yes" or "Run Once"
3. ✅ **COLOR-CODED** output shows exactly what's happening

## 🔧 Manual Method (Backup)

If scripts don't work, follow these **EXACT** steps:

### Windows Command Prompt:
```cmd
cd /d "C:\Users\OMISTAJA\Documents\GitHub\CalendarApp\calendar_app"
dir pubspec.yaml
flutter run -d chrome
```

### PowerShell:
```powershell
Set-Location "C:\Users\OMISTAJA\Documents\GitHub\CalendarApp\calendar_app"
Test-Path "pubspec.yaml"
flutter run -d chrome
```

## 🛠️ Troubleshooting

### ❌ Problem: "flutter is not recognized"
**Solution:** Flutter is not in your PATH. Follow these steps:

1. Press `Windows + R`, type `sysdm.cpl`, press Enter
2. Click "Environment Variables"
3. Under "User variables", find or create "Path"
4. Add your Flutter installation path (e.g., `C:\src\flutter\bin`)
5. **Restart** your terminal/command prompt
6. Test with: `flutter --version`

### ❌ Problem: "No pubspec.yaml file found"
**Solution:** You're in the wrong directory. The correct structure is:
```
CalendarApp/
├── run_flutter.bat     ← Run this
├── run_flutter.ps1     ← Or this
└── calendar_app/       ← Flutter project is HERE
    ├── pubspec.yaml    ← This file must exist
    ├── lib/
    └── ...
```

### ❌ Problem: Scripts won't run
**Solutions:**
1. **For .bat files:** Right-click → "Run as administrator"
2. **For .ps1 files:** 
   - Open PowerShell as admin
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
   - Try the script again

## 📁 File Locations

All these files should be in your `CalendarApp` root directory:
- ✅ `run_flutter.bat` - Windows batch script
- ✅ `run_flutter.ps1` - PowerShell script  
- ✅ `FLUTTER_RUN_INSTRUCTIONS.md` - This file
- 📁 `calendar_app/` - Your Flutter project folder

## 🎮 VS Code Method

If you prefer VS Code:
1. Open VS Code
2. File → Open Folder → Select `CalendarApp/calendar_app` (NOT the root CalendarApp)
3. Open terminal in VS Code (`Ctrl + \``)
4. Run: `flutter run -d chrome`

## 🔍 Verification Commands

To verify everything is working:
```cmd
flutter doctor -v
flutter devices
flutter --version
```

## 🚨 Emergency Reset

If nothing works:
1. Close ALL terminals and command prompts
2. Restart your computer
3. Use the batch file: `run_flutter.bat`
4. If still fails, check if Flutter is properly installed

---

## 💡 Pro Tips

- **Always use the scripts** - they handle directory navigation automatically
- **Keep terminals closed** when not in use to avoid confusion
- **The batch file is foolproof** - it checks everything before running
- **PowerShell script shows colored output** for easier debugging

---

**🎯 Bottom line:** Use `run_flutter.bat` and never worry about directories again! 