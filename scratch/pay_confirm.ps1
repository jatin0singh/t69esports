$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"

# Tap Pay Rs 50 & Confirm LEFT SIDE at x=500, y=2300
& $adb -s emulator-5554 shell input tap 500 2300
Start-Sleep -Seconds 3

# Pull ticket voucher screenshot
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_cs_voucher_confirmed.png"
Write-Host "Captured CS Voucher Confirmation Dialog"
