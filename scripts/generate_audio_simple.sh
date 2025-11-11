#!/bin/bash
# Generate simple audio files using macOS built-in tools
# This script uses sox (if available) or ffmpeg to generate audio files

set -e

OUTPUT_DIR="../clock-tsukiusagi/Resources/Audio"
SAMPLE_RATE=44100
DURATION=60

echo "🎵 Generating audio files for clock-tsukiusagi..."
echo "   Sample rate: ${SAMPLE_RATE} Hz"
echo "   Duration: ${DURATION} seconds"
echo "   Output: ${OUTPUT_DIR}/"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check for available tools
HAS_SOX=false
HAS_FFMPEG=false

if command -v sox &> /dev/null; then
    HAS_SOX=true
    echo "✓ Found sox"
fi

if command -v ffmpeg &> /dev/null; then
    HAS_FFMPEG=true
    echo "✓ Found ffmpeg"
fi

if [ "$HAS_SOX" = false ] && [ "$HAS_FFMPEG" = false ]; then
    echo "❌ Error: Neither sox nor ffmpeg found"
    echo ""
    echo "Please install one of:"
    echo "  brew install sox"
    echo "  brew install ffmpeg"
    exit 1
fi

echo ""

# Function to generate pink noise using sox
generate_pink_noise_sox() {
    local output="$1"
    echo "Generating pink noise (sox)..."
    sox -n -r "$SAMPLE_RATE" -c 1 -b 16 "$output" synth "$DURATION" pinknoise fade 0.1 "$DURATION" 0.1
}

# Function to generate pink noise using ffmpeg
generate_pink_noise_ffmpeg() {
    local output="$1"
    echo "Generating pink noise (ffmpeg)..."
    ffmpeg -f lavfi -i "anoisesrc=d=${DURATION}:c=pink:r=${SAMPLE_RATE}:a=0.5" \
           -af "afade=t=in:st=0:d=0.1,afade=t=out:st=$((DURATION-1)):d=0.1" \
           -ar "$SAMPLE_RATE" -ac 1 -y "$output" 2>&1 | grep -v "^frame=" || true
}

# Function to generate brownian noise (deeper than pink)
generate_brown_noise_sox() {
    local output="$1"
    echo "Generating brown noise (sox)..."
    sox -n -r "$SAMPLE_RATE" -c 1 -b 16 "$output" synth "$DURATION" brownnoise fade 0.1 "$DURATION" 0.1
}

generate_brown_noise_ffmpeg() {
    local output="$1"
    echo "Generating brown noise (ffmpeg)..."
    ffmpeg -f lavfi -i "anoisesrc=d=${DURATION}:c=brown:r=${SAMPLE_RATE}:a=0.5" \
           -af "afade=t=in:st=0:d=0.1,afade=t=out:st=$((DURATION-1)):d=0.1" \
           -ar "$SAMPLE_RATE" -ac 1 -y "$output" 2>&1 | grep -v "^frame=" || true
}

# Function to generate sine wave tone
generate_sine_tone_sox() {
    local output="$1"
    local freq="$2"
    echo "Generating sine tone ${freq}Hz (sox)..."
    sox -n -r "$SAMPLE_RATE" -c 1 -b 16 "$output" synth "$DURATION" sine "$freq" fade 0.2 "$DURATION" 0.2
}

generate_sine_tone_ffmpeg() {
    local output="$1"
    local freq="$2"
    echo "Generating sine tone ${freq}Hz (ffmpeg)..."
    ffmpeg -f lavfi -i "sine=f=${freq}:d=${DURATION}:r=${SAMPLE_RATE}" \
           -af "afade=t=in:st=0:d=0.2,afade=t=out:st=$((DURATION-1)):d=0.2,volume=0.3" \
           -ar "$SAMPLE_RATE" -ac 1 -y "$output" 2>&1 | grep -v "^frame=" || true
}

# Generate audio files
echo "1/3 Generating pink noise..."
if [ "$HAS_SOX" = true ]; then
    generate_pink_noise_sox "$OUTPUT_DIR/pink_noise_60s.wav"
else
    generate_pink_noise_ffmpeg "$OUTPUT_DIR/pink_noise_60s.wav"
fi

# Convert to CAF
if [ -f "$OUTPUT_DIR/pink_noise_60s.wav" ]; then
    afconvert -f caff -d LEI16 "$OUTPUT_DIR/pink_noise_60s.wav" "$OUTPUT_DIR/pink_noise_60s.caf"
    echo "✓ Converted to CAF: pink_noise_60s.caf"
fi
echo ""

echo "2/3 Generating brown noise (deeper relaxation)..."
if [ "$HAS_SOX" = true ]; then
    generate_brown_noise_sox "$OUTPUT_DIR/brown_noise_60s.wav"
else
    generate_brown_noise_ffmpeg "$OUTPUT_DIR/brown_noise_60s.wav"
fi

# Convert to CAF
if [ -f "$OUTPUT_DIR/brown_noise_60s.wav" ]; then
    afconvert -f caff -d LEI16 "$OUTPUT_DIR/brown_noise_60s.wav" "$OUTPUT_DIR/brown_noise_60s.caf"
    echo "✓ Converted to CAF: brown_noise_60s.caf"
fi
echo ""

echo "3/3 Generating low-frequency drone (165Hz)..."
if [ "$HAS_SOX" = true ]; then
    generate_sine_tone_sox "$OUTPUT_DIR/drone_165hz_60s.wav" 165
else
    generate_sine_tone_ffmpeg "$OUTPUT_DIR/drone_165hz_60s.wav" 165
fi

# Convert to CAF
if [ -f "$OUTPUT_DIR/drone_165hz_60s.wav" ]; then
    afconvert -f caff -d LEI16 "$OUTPUT_DIR/drone_165hz_60s.wav" "$OUTPUT_DIR/drone_165hz_60s.caf"
    echo "✓ Converted to CAF: drone_165hz_60s.caf"
fi
echo ""

# List generated files
echo "✅ All audio files generated successfully!"
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR"/*.{wav,caf} 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "📝 Next steps:"
echo "   1. Add audio files to Xcode project"
echo "   2. Set Target Membership to 'clock-tsukiusagi'"
echo "   3. Verify files appear in Copy Bundle Resources build phase"
