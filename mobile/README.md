# UDI Shopping Flutter client

This directory contains the Flutter Android client source for UDI Shopping.

## Setup
1. Install Flutter SDK and Android Studio.
2. From this directory, run `flutter create . --platforms android` to generate the Android runner files.
3. Run `flutter pub get`.
4. Start the Django API on your development machine.
5. Run on the Android emulator with `flutter run`. The default API URL is `http://10.0.2.2:8000/api/v1`.
6. For a physical phone or hosted API, pass `--dart-define=API_BASE_URL=https://your-api-host/api/v1`.

The API client stores access and refresh tokens using platform secure storage. Payment UI is not enabled until the backend and Razorpay test credentials have been validated end-to-end.
