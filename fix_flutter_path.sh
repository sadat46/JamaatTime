#!/bin/bash

# Add Git to PATH for Flutter
export PATH="/c/Program Files/Git/bin:$PATH"

# Set Flutter root
export FLUTTER_ROOT="/c/src/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"

echo "Git version:"
git --version

echo ""
echo "Flutter version:"
flutter --version

echo ""
echo "Running flutter analyze..."
flutter analyze 