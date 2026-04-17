import os
import sys

# Add current dir to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    import voice_agent
    print("✅ voice_agent imported successfully")
except Exception as e:
    print(f"❌ Failed to import voice_agent: {e}")
    sys.exit(1)

transcript = "from saveetha university to koyambedu"
print(f"Testing transcript: '{transcript}'")

try:
    result = voice_agent.parse_voice_intent(transcript)
    print(f"✅ Result: {result}")
except Exception as e:
    print(f"❌ parse_voice_intent failed: {e}")
    import traceback
    traceback.print_exc()
