$adb = "C:\Users\chouh\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb -s emulator-5554 shell screencap -p /sdcard/screen.png
& $adb -s emulator-5554 pull /sdcard/screen.png "C:\Users\chouh\.gemini\antigravity\brain\3079f17e-14dd-4c4e-8eae-da6eeb38a7c1\live_clash_squad_home.png"
Write-Host "Pulled valid PNG successfully"
