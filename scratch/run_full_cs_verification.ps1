$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"

# 1. Tap 1v1 DUEL tab at x=200, y=600
& $adb -s emulator-5554 shell input tap 200 600
Start-Sleep -Milliseconds 600

# 2. Tap Register Lobby (Rs 50) at x=500, y=1520
& $adb -s emulator-5554 shell input tap 500 1520
Start-Sleep -Seconds 2

# Pull modal view
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_cs_reg_modal.png"
Write-Host "Captured CS Registration Modal"
