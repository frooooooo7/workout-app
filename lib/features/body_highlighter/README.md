# Body Highlighter Widget

A Flutter widget that displays an interactive anatomical body model with muscle highlighting capabilities. Features both front and back views with support for dynamic muscle highlighting at multiple intensity levels.

## Features

- ✨ Front and back body views
- 🎯 Dynamic muscle highlighting with 4 intensity levels
- 👆 Interactive tap detection for individual muscles
- 🎨 Customizable color scheme (dark/light themes)
- 📱 Responsive scaling without deformation
- ⚡ Efficient caching of SVG paths
- 🎭 Support for left/right side selection
- 🔄 Smooth color transitions between states

## Usage

### Basic Example

```dart
import 'package:gym/features/body_highlighter/widgets/muscle_body_highlighter.dart';
import 'package:gym/features/body_highlighter/models/body_view.dart';
import 'package:gym/features/body_highlighter/models/muscle_highlight.dart';
import 'package:gym/features/body_highlighter/models/muscle_intensity.dart';

MuscleBodyHighlighter(
  view: BodyView.front,
  highlights: {
    MuscleHighlight(
      muscle: 'chest',
      intensity: MuscleIntensity.high,
    ),
    MuscleHighlight(
      muscle: 'biceps',
      intensity: MuscleIntensity.medium,
      side: BodySide.left,
    ),
  },
  onMuscleSelected: (muscle, side) {
    print('Selected: $muscle on $side');
  },
)
```

### Dual View (Front + Back)

```dart
import 'package:gym/features/body_highlighter/widgets/front_back_body_highlighter.dart';

FrontBackBodyHighlighter(
  frontHighlights: frontSet,
  backHighlights: backSet,
  style: BodyHighlighterStyle.dark(),
  onMuscleSelected: (muscle, view, side) {
    print('$view - $muscle - $side');
  },
)
```

## Models

### BodyView
- `front`: Display front side of the body
- `back`: Display back side of the body

### MuscleIntensity
- `inactive` (0): Default inactive color
- `low` (1): Low intensity highlight
- `medium` (2): Medium intensity highlight
- `high` (3): High intensity highlight

### BodySide
- `left`: Left side of the body
- `right`: Right side of the body
- `common`: Both sides (symmetric)

### MuscleHighlight
```dart
MuscleHighlight(
  muscle: String,              // e.g., 'chest', 'biceps'
  intensity: MuscleIntensity,  // Highlight level
  side: BodySide?,             // Optional: limit to specific side
)
```

## Styling

### Dark Theme (Default)

```dart
BodyHighlighterStyle.dark()
```

Characteristics:
- Dark navy inactive color
- Gray-blue outline
- Blue active highlights
- Subtle glow effect on high intensity

### Light Theme

```dart
BodyHighlighterStyle.light()
```

Characteristics:
- Light gray inactive color
- Blue-gray outline
- Brighter blue highlights

### Custom Style

```dart
BodyHighlighterStyle(
  inactiveFill: Color(0xFF2C3E50),
  inactiveStroke: Color(0xFF34495E),
  lowColor: Color(0xFF74B9FF),
  mediumColor: Color(0xFF0984E3),
  highColor: Color(0xFF0563C1),
  activeStroke: Color(0xFF0984E3),
  outlineStroke: Color(0xFF34495E),
  strokeWidth: 0.5,
  glowEnabled: true,
)
```

## Available Muscles

### Front View
- chest
- abs
- obliques
- biceps
- triceps
- deltoids
- trapezius
- quadriceps
- adductors
- tibialis
- calves
- forearm
- hands
- ankles
- feet
- head
- hair
- neck

### Back View
- upper-back
- lower-back
- triceps
- trapezius
- deltoids
- neck
- forearm
- gluteal
- adductors
- hamstring
- calves
- hands
- ankles
- feet
- head
- hair

## Architecture

### Data Flow

1. **Asset Loading**: JSON files loaded from assets directory
2. **Path Parsing**: SVG paths converted to Flutter `Path` objects (cached)
3. **Rendering**: `CustomPaint` renders paths based on highlight state
4. **Interaction**: Tap coordinates mapped to path hit-testing

### File Structure

```
body_highlighter/
├── data/
│   ├── body_data_service.dart      # Data loading & caching
│   ├── body_highlighter_asset_loader.dart
│   └── svg_path_parser.dart        # SVG path parsing
├── models/
│   ├── body_view.dart
│   ├── body_side.dart
│   ├── muscle_intensity.dart
│   ├── muscle_highlight.dart
│   ├── muscle_region.dart
│   ├── body_model_data.dart
│   └── body_highlighter_style.dart
├── painters/
│   └── body_highlighter_painter.dart  # Canvas rendering
├── widgets/
│   ├── muscle_body_highlighter.dart    # Single view widget
│   └── front_back_body_highlighter.dart # Dual view widget
└── demo/
    └── body_highlighter_demo_screen.dart
```

## Performance Considerations

- **Path Caching**: SVG paths are parsed once and cached in memory
- **Efficient Repainting**: Only repaints when `highlights` change
- **Scale Calculation**: Aspect ratio preserved without distortion
- **Hit Testing**: Uses native `Path.contains()` for accurate tap detection

## Limitations

- Arc paths (A/a commands) simplified to line approximations
- Animation support planned for future releases
- Female body model available via separate JSON (future)

## License

See [LICENSE_NOTICE.md](LICENSE_NOTICE.md) for original work attribution.

Original React Native component by ELABBASSI Hicham (MIT License)
Flutter adaptation maintains compatibility with original design.
