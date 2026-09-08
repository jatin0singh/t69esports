$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"

# 1. Back to Home
& $adb -s emulator-5554 shell input keyevent 4
Start-Sleep -Milliseconds 600

# 2. Tap Free Fire or Clash Squad tile
& $adb -s emulator-5554 shell input tap 140 1300
Start-Sleep -Seconds 2

# 3. Pull screenshot of Clash Squad tab in FreeFireHubScreen
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_cs_hub_view.png"
Write-Host "Captured Clash Squad hub view"
