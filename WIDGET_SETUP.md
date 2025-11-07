# GMJuice Widget Setup Instructions

This guide will help you add the Steel Challenge Progress widget to your GMJuice app.

## Overview

The widget displays:
- **Division & Classification**: e.g., "RFPO · GM"
- **Total Time**: Sum of classification stage times (e.g., "71.25s")
- **Performance Percentage**: Performance vs GM peak (e.g., "97%")
- **Days Since Last Match**: Time since your last competition
- **Auto-rotation**: If you shoot multiple divisions, the widget rotates between them every 2 hours

The widget uses the same box styling as the Analysis view and supports both medium (2x1) and large (2x2) sizes.

## Setup Steps

### 1. Add Widget Extension Target in Xcode

1. Open `GMJuice.xcodeproj` in Xcode
2. Go to **File > New > Target**
3. Select **Widget Extension**
4. Configure the widget:
   - Product Name: `GMJuiceWidget`
   - Team: (your development team)
   - Include Configuration Intent: **NO** (we don't need user configuration)
5. Click **Finish**
6. When prompted "Activate 'GMJuiceWidget' scheme?", click **Activate**

### 2. Replace Generated Widget Files

The widget template will generate some default files. Replace them with our custom files:

1. **Delete** the generated files in the GMJuiceWidget folder:
   - `GMJuiceWidget.swift` (keep the one we created)
   - `GMJuiceWidgetBundle.swift` (if generated separately)
   - `GMJuiceWidgetLiveActivity.swift` (if generated)
   - `AppIntent.swift` (if generated)

2. **Add** our widget files to the GMJuiceWidget target:
   - `GMJuiceWidget/GMJuiceWidget.swift`
   - `GMJuiceWidget/WidgetDataProvider.swift`
   - `GMJuiceWidget/WidgetViews.swift`
   - `GMJuiceWidget/Info.plist`

### 3. Add Shared Files to Widget Target

The widget needs access to some data model files. In Xcode:

1. Select these files in the Project Navigator (⌘-click to multi-select):
   - `GMJuice/Data/Division.swift`
   - `GMJuice/Data/ShooterClass.swift`
   - `GMJuice/Persistence/Schemas.swift`
   - `GMJuice/Persistence/ModelAliases.swift`

2. In the **File Inspector** (right panel), under **Target Membership**, also check **GMJuiceWidget**

This allows the widget to use the same data models as the main app.

### 4. Configure App Groups

App Groups allow the main app and widget to share data.

#### 4.1 Create App Group in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers**
4. Click the **+** button to add a new identifier
5. Select **App Groups** and click **Continue**
6. Set the identifier to: `group.com.andre.GMJuice` (or adjust based on your bundle ID)
7. Click **Register**

#### 4.2 Enable App Groups in App IDs

For both your main app and widget:

1. Select your **GMJuice app identifier**
2. Enable **App Groups** capability
3. Click **Edit** and select `group.com.andre.GMJuice`
4. Click **Save**

Repeat for the **GMJuiceWidget extension** identifier.

#### 4.3 Add App Groups in Xcode

1. Select the **GMJuice** project in Project Navigator
2. Select the **GMJuice** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **App Groups**
6. Check (or add) `group.com.andre.GMJuice`

Repeat the same steps for the **GMJuiceWidget** target.

### 5. Update Bundle Identifiers (if needed)

If your main app bundle ID is different from `com.andre.GMJuice`:

1. Update the App Group ID in:
   - `GMJuice/GMJuice.swift` line 52
   - `GMJuiceWidget/WidgetDataProvider.swift` line 143

   Replace `group.com.andre.GMJuice` with your App Group ID.

### 6. Build and Run

1. Select the **GMJuice** scheme
2. Build and run the app (⌘R)
3. The app will now store data in the shared App Group container

### 7. Add Widget to Home Screen

1. Long-press on your home screen
2. Tap the **+** button (top-left)
3. Search for "GMJuice"
4. Select the **Steel Challenge Progress** widget
5. Choose size (Medium or Large)
6. Tap **Add Widget**

## Widget Behavior

### Medium Widget (2x1)
Shows 3 metrics in compact boxes:
- Total classification time
- Performance percentage
- Days since last match

### Large Widget (2x2)
Shows all metrics plus:
- Full division name
- Current classification name
- Next classification target
- Percentage needed for next class

### Data Refresh
- Updates every 2 hours
- Rotates between divisions (if you shoot multiple)
- Shows most recent match data

### Rotation Logic
If you have classifications in multiple divisions (e.g., RFPO and CO), the widget automatically rotates between them:
- 12am-2am: Division 1
- 2am-4am: Division 2
- 4am-6am: Division 1
- And so on...

This ensures you see progress across all your divisions throughout the day.

## Troubleshooting

### Widget Shows "No Match Data"
- Make sure you have SCMatchScore entries with `usedForClassification = true`
- Check that your ShooterProfile has DivisionProfile entries with non-U classifications
- Verify App Groups are properly configured in both targets

### Widget Not Updating
- Check that the App Group ID matches in all locations
- Ensure the widget target has access to the shared model files
- Try removing and re-adding the widget to the home screen

### Build Errors
- Make sure all shared files have both targets checked in Target Membership
- Verify App Groups capability is enabled in both targets
- Check that the Info.plist is properly configured

## Testing the Widget

During development, you can test the widget:

1. Run the **GMJuiceWidget** scheme (select it in Xcode)
2. This runs the widget in isolation with preview data
3. Make changes and see them update in real-time

For testing with real data:
1. Run the main **GMJuice** app
2. Add some match scores with classification data
3. Add the widget to your home screen
4. The widget should display your actual performance data

## Next Steps

Once the widget is working:
- Compete in matches and import scores via SCSA scraper
- Watch your classification progress update on your home screen
- Use multiple widget instances to track different metrics
- Consider adding widget to Lock Screen (iOS 16+) for quick access

Enjoy tracking your Steel Challenge progress!
