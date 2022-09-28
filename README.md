# ios-bluetooth-peripheral

Quick CoreBluetooth peripheral implementation to expose data both via GATT Characteristic updates and an L2CAP channel.

Part of investigating some delays in receiving characteristic updates on some iOS devices.

See https://developer.apple.com/forums/thread/713800 for more details.

Run this on one device, and the https://github.com/tangobravo/ios-bluetooth-central app on another one.

## Known issue

This doesn't handle the channel being closed gracefully, so you'll need to kill this app and restart it whenever the central app is restarted.
