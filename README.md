# SPCXTicker

A floating, always-on-top macOS widget that shows the SPCX stock price on an LED dot-matrix panel.

- `$SPCX`, percent change, and price rendered in a 5×7 pixel font
- A rocket on the right: green at 45° when the stock is up, red and pointing down when it's down
- Polls Yahoo Finance every 60 seconds

## Run

```sh
swift build
./.build/debug/SPCXTicker
```

Drag the black panel to move it. Requires macOS 14 or later.
