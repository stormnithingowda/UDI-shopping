# UDI Shopping Flutter client

This directory contains the Flutter Android customer app.

## Included customer flows

- Register and sign in with JWT authentication; access tokens are stored with platform secure storage and refreshed after an API 401 response.
- Browse the public product catalogue.
- Add products to the cart and update or remove cart items.
- Save products to a wishlist and move them to the cart.
- Manage delivery addresses (add, edit, delete unused addresses, and choose a default).
- Place an order and open Razorpay Standard Checkout in test mode.
- Send the Razorpay checkout callback to the backend for signature and captured-payment verification.
- Review order history, order details, and status history.

## Setup

1. Install the stable Flutter SDK and Android Studio with an Android SDK.
2. From this directory, generate the Android runner files once: `flutter create . --platforms android`.
3. Run `flutter pub get`.
4. Start the Django API on your development machine.
5. Run on the Android emulator:
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.
6. For a physical Android phone, use the development computer's LAN IP address in `API_BASE_URL`. The phone and computer must be able to reach each other.
7. For a hosted API, use an HTTPS URL:
   `flutter run --dart-define=API_BASE_URL=https://your-api-host/api/v1`.

For local HTTP development only, configure Android cleartext access in the debug manifest/build configuration. Do not enable cleartext traffic in a release build. Use HTTPS for hosted and production deployments.

## Payment security

The app receives only the public Razorpay Key ID and a server-created Razorpay order ID from Django. The Razorpay Key Secret and webhook secret must remain in the backend environment. The app never treats a client success callback as final payment confirmation; the backend verifies the signature and independently fetches the captured payment from Razorpay.

## Checks

Run these commands from this directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The Android runner may need to be generated first with `flutter create . --platforms android`.
