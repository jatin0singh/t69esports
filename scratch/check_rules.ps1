$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFyZHlycndqaGdycGVpbHRncmRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwNzQyOTQsImV4cCI6MjEwMjY1MDI5NH0.GGFCWzXMm9krqcQ1v8BvgQiAwwzHYyYTlNBPUuxfyvE"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFyZHlycndqaGdycGVpbHRncmRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwNzQyOTQsImV4cCI6MjEwMjY1MDI5NH0.GGFCWzXMm9krqcQ1v8BvgQiAwwzHYyYTlNBPUuxfyvE"
}

$t = Invoke-RestMethod -Uri "https://ardyrrwjhgrpeiltgrdl.supabase.co/rest/v1/tournaments?title=ilike.*FF Squad Mayhem - Lobby #1*&select=*" -Headers $headers
$t | ConvertTo-Json -Depth 5
