const String webInterfaceHTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SoundShare | Listen Live</title>
    <style>
        body {
            background-color: #0f172a;
            color: #f8fafc;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            background-color: #1e293b;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.5);
            text-align: center;
            max-width: 400px;
            width: 90%;
        }
        h1 { color: #38bdf8; margin-bottom: 10px; }
        p { color: #94a3b8; margin-bottom: 30px; }
        .btn {
            background-color: #0ea5e9;
            color: white;
            border: none;
            padding: 15px 30px;
            font-size: 18px;
            font-weight: bold;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s;
            width: 100%;
        }
        .btn:hover { background-color: #0284c7; transform: scale(1.05); }
        .btn.playing { background-color: #ef4444; }
        .btn.playing:hover { background-color: #dc2626; }
        .pulse {
            display: none;
            margin-top: 20px;
            color: #22c55e;
            font-weight: bold;
            animation: blink 1.5s infinite;
        }
        @keyframes blink { 50% { opacity: 0; } }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎧 SoundShare</h1>
        <p>Streaming directly from Boss's PC</p>
        
        <button id="playBtn" class="btn">Connect & Listen</button>
        <div id="status" class="pulse">🔴 LIVE STREAMING ACTVE</div>
        
        <audio id="audioPlayer" crossorigin="anonymous">
            <source src="/stream" type="audio/wav">
        </audio>
    </div>

    <script>
        const playBtn = document.getElementById('playBtn');
        const audioPlayer = document.getElementById('audioPlayer');
        const status = document.getElementById('status');
        let isPlaying = false;

        playBtn.addEventListener('click', () => {
            if (!isPlaying) {
                audioPlayer.src = "/stream?" + new Date().getTime(); 
                audioPlayer.play().then(() => {
                    playBtn.textContent = 'Stop Listening';
                    playBtn.classList.add('playing');
                    status.style.display = 'block';
                    isPlaying = true;
                }).catch(e => alert("Autoplay blocked! Click again."));
            } else {
                audioPlayer.pause();
                audioPlayer.currentTime = 0;
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