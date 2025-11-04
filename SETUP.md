# GMJuice Setup Instructions

## API Key Configuration

The app uses the Anthropic API for AI-powered coaching features. To run the app on a device or simulator, you need to configure your API key.

### 1. Get Your API Key
1. Visit https://console.anthropic.com/settings/keys
2. Create a new API key (or use an existing one)
3. Copy the key (starts with `sk-ant-api03-...`)

### 2. Configure the Key Locally

**Edit `Config.xcconfig`:**
```bash
# Open the file
open Config.xcconfig
```

Replace `sk-ant-api03-YOUR-KEY-HERE` with your actual API key:
```
ANTHROPIC_API_KEY = sk-ant-api03-your-actual-key-here
```

### 3. Link Config File in Xcode (One-time setup)

**IMPORTANT:** You need to tell Xcode to use the Config.xcconfig file:

1. Open `GMJuice.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "GMJuice")
3. In the "Info" tab, find the "Configurations" section
4. For both **Debug** and **Release**:
   - Click the disclosure triangle next to the configuration name
   - Under "GMJuice" target, select `Config` from the dropdown
   - (If Config doesn't appear, you may need to add it: click "+" and select Config.xcconfig)

**Alternative: Use Xcode command line**
```bash
# This sets the configuration for Debug and Release builds
xcodebuild -project GMJuice.xcodeproj -showBuildSettings | grep ANTHROPIC_API_KEY
```

### 4. Verify Setup

Build and run the app. The `CoachingService` will:
1. ✅ Try environment variable `ANTHROPIC_API_KEY` (for CLI builds)
2. ✅ Fall back to `Info.plist` which gets the value from `Config.xcconfig` at build time

### How It Works

- `Config.xcconfig` defines `ANTHROPIC_API_KEY = your-key`
- At build time, Xcode injects this into `Info.plist`
- `Info.plist` contains `<string>$(ANTHROPIC_API_KEY)</string>`
- The app reads the resolved value at runtime
- `Config.xcconfig` is in `.gitignore` so your key stays secret

### Troubleshooting

**"Anthropic API key not configured" error:**
1. Verify `Config.xcconfig` has your real API key
2. Verify Xcode project is configured to use Config.xcconfig (see step 3)
3. Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
4. Rebuild the app

**Still not working?**
Check if the xcconfig is being used:
```bash
xcodebuild -project GMJuice.xcodeproj \
  -scheme GMJuice \
  -configuration Debug \
  -showBuildSettings | grep ANTHROPIC_API_KEY
```

You should see: `ANTHROPIC_API_KEY = sk-ant-api03-...`
