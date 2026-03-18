# Sri Keyan Music API - Cloud Deployment

## Deploy to Render.com (Free Tier)

### Option 1: Deploy via Render Dashboard

1. Go to [render.com](https://render.com) and sign up/login
2. Click "New +" → "Web Service"
3. Connect your GitHub repository (or create a new one with this folder)
4. Configure the service:
   - **Name**: `sri-keyan-api`
   - **Environment**: `Python`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `python render_server.py`
   - **Plan**: Free

5. Add Environment Variable:
   - Key: `PORT`, Value: `10000`

6. Click "Create Web Service"

### Option 2: Deploy via CLI

```bash
pip install render
render deploy
```

## After Deployment

Once deployed, you'll get a URL like: `https://sri-keyan-api.onrender.com`

Update your Flutter app with this URL:
```bash
flutter run --dart-define=API_URL=https://sri-keyan-api.onrender.com
```

Or update the default in `lib/main.dart`:
```dart
static String get _baseUrl {
  if (kIsWeb) {
    return const String.fromEnvironment('API_URL', defaultValue: 'https://sri-keyan-api.onrender.com');
  }
  return 'http://localhost:5000';
}
```

## Important Notes

- The free tier spins down after 15 minutes of inactivity
- First request after idle may take ~30 seconds to wake up
- For production, consider upgrading to a paid plan
