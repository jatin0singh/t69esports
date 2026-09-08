$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"

# 1. Scroll down to bottom of modal
& $adb -s emulator-5554 shell input swipe 500 1800 500 600 300
Start-Sleep -Milliseconds 600

# 2. Tap Confirm Booking Button (at bottom around y=2100)
& $adb -s emulator-5554 shell input tap 500 2100
Start-Sleep -Seconds 2

# 3. Pull ticket voucher screenshot
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_cs_voucher.png"
Write-Host "Captured CS Voucher / Room"
