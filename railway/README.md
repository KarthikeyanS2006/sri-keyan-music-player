Sri Keyan Music API - Railway Deployment

## Deploy to Railway.app

1. Go to https://railway.app and sign up/login with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select this repository
4. Set the Root Directory to `railway`
5. Add Environment Variable:
   - `PORT`: `8080`
   - `YT_HEADERS`: (your headers_auth.json content)
6. Click "Deploy"

Railway automatically installs FFmpeg, which yt-dlp needs for audio extraction.

After deployment, update the Flutter app with the Railway URL.
