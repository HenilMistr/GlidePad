## Connection
- Phone scans for BLE devices named `TrackPadHost_*`
- Connects → requests profile via `{ "cmd": "request_profile" }`

## Messages: Phone → Laptop
{ "cmd": "move", "dx": 5, "dy": -3 }
{ "cmd": "tap", "fingers": 1 }
{ "cmd": "scroll", "dy": 8 }

## Messages: Laptop → Phone
{
  "profile": {
    "os": "windows|macos",
    "naturalScroll": true|false,
    "tapToClick": true|false,
    "hasPrecisionTouchpad": true|false
  }
}

## Gesture Adaptation Logic (Phone Side)
if (profile.os == 'macos' && profile.naturalScroll) {
  scrollMultiplier = 1.0;
} else {
  scrollMultiplier = -1.0;
}