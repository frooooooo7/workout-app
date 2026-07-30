# Body Highlighter License

This feature contains code adapted from:
**react-native-body-highlighter** by ELABBASSI Hicham
- Repository: https://github.com/HichamELBSI/react-native-body-highlighter
- License: MIT

## Original License Text

MIT License

Copyright (c) 2022 ELABBASSI Hicham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Adaptation Notes

The original React Native component has been adapted to native Flutter with the following changes:

1. **SVG Path Parsing**: Implemented native SVG path parser in Dart (original used react-native-svg)
2. **Rendering**: Used Flutter's CustomPaint and Canvas instead of React Native SVG component
3. **Data Format**: Converted TypeScript data structures to JSON and Dart models
4. **Architecture**: Implemented following Flutter best practices with FutureBuilder, caching, and clean separation of concerns

The core anatomical data and SVG path definitions remain largely unchanged to preserve the original design accuracy.
