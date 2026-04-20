const String webInterfaceHTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SoundShare | Listen Live</title>
    <style>
        body { background-color: #0f172a; color: #f8fafc; font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .container { background-color: #1e293b; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; width: 90%; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        h1 { color: #38bdf8; }
        .btn { background-color: #0ea5e9; color: white; border: none; padding: 15px 30px; font-size: 18px; font-weight: bold; border-radius: 8px; cursor: pointer; transition: 0.3s; width: 100%; }
        .btn:hover { background-color: #0284c7; }
        .btn.playing { background-color: #ef4444; }
        .pulse { display: none; margin-top: 20px; color: #22c55e; font-weight: bold; animation: blink 1.5s infinite; }
        @keyframes blink { 50% { opacity: 0; } }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎧 SoundShare</h1>
        <p>Boss's Live Audio Stream</p>
        <button id="playBtn" class="btn">Connect & Listen</button>
        <div id="status" class="pulse">🔴 LIVE STREAMING ACTIVE</div>
        <audio id="audioPlayer" crossorigin="anonymous"></audio>
    </div>
    <script>
        const playBtn = document.getElementById('playBtn');
        const audioPlayer = document.getElementById('audioPlayer');
        const status = document.getElementById('status');
        let isPlaying = false;

        playBtn.addEventListener('click', async () => {
            if (!isPlaying) {
                try {
                    playBtn.textContent = 'Connecting...';
                    audioPlayer.src = "/stream?t=" + Date.now();
                    await audioPlayer.play();
                    playBtn.textContent = 'Stop Listening';
                    playBtn.classList.add('playing');
                    status.style.display = 'block';
                    isPlaying = true;
                } catch (e) {
                    alert("Click again! Browser blocked initial playback.");
                    playBtn.textContent = 'Connect & Listen';
                }
            } else {
                audioPlayer.pause();
                audioPlayer.src = "";
                playBtn.textContent = 'Connect & Listen';
                playBtn.classList.remove('playing');
                status.style.display = 'none';
                isPlaying = false;
            }
        });
    </script>
</body>
</html>
""";