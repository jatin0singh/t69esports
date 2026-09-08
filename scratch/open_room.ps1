$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"

# Tap Open Match Room at x=600, y=1660
& $adb -s emulator-5554 shell input tap 600 1660
Start-Sleep -Seconds 2

# Pull Lobby Room Screen
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_cs_lobby_room.png"
Write-Host "Captured CS Lobby Room"
