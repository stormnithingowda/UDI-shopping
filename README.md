# UDI Shopping

UDI Shopping is a Flutter Android shopping client backed by a Django REST API and PostgreSQL. The application is being developed and validated in Razorpay test mode.

## Features

### Customer app
- Customer registration, login, and secure local token storage
- Product catalogue and product details
- Customer-owned cart and wishlist
- Delivery address list, create, edit, delete, and default-address selection
- Checkout with server-side stock validation and pending-payment order creation
- Razorpay Standard Checkout in test mode
- Server-side payment signature and captured-payment verification
- Order history, order details, and status-history tracking

### Backend and administration
- Django 5.2 and Django REST Framework
- PostgreSQL configuration with SQLite fallback for local development
- JWT authentication
- Customer-owned commerce records with ownership checks
- Transactional checkout and inventory reservation
- Razorpay webhook signature validation and event-ID deduplication
- Django admin product catalogue management
- Controlled order fulfillment actions: confirmed → processing → shipped → delivered
- Read-only payment and webhook audit records in Django admin

## API routes

- `POST /api/v1/commerce/register/` — create a customer account and receive JWT tokens
- `POST /api/v1/auth/token/` — obtain JWT access and refresh tokens
- `POST /api/v1/auth/token/refresh/` — refresh an access token
- `GET /api/v1/catalog/products/` — public product list
- `GET /api/v1/catalog/products/<slug>/` — public product details
- `GET|POST|DELETE /api/v1/commerce/cart/` — current user's cart
- `PATCH|DELETE /api/v1/commerce/cart/items/<id>/` — update or remove a cart item
- `GET|POST|DELETE /api/v1/commerce/wishlist/` — current user's wishlist
- `POST /api/v1/commerce/wishlist/<id>/move-to-cart/` — add a saved product to the cart
- `GET|POST /api/v1/commerce/addresses/` — list or create delivery addresses
- `PATCH|DELETE /api/v1/commerce/addresses/<id>/` — edit or delete an unused delivery address
- `POST /api/v1/commerce/checkout/` — create a pending-payment order; JSON body: `{"address_id": 1}`
- `POST /api/v1/commerce/orders/<id>/payment/create/` — create a Razorpay payment order
- `POST /api/v1/commerce/orders/<id>/payment/verify/` — verify signature and captured payment with Razorpay
- `POST /api/v1/commerce/payments/razorpay/webhook/` — receive signed and deduplicated Razorpay payment events
- `GET /api/v1/commerce/orders/` — current user's orders
- `GET /api/v1/commerce/orders/<id>/` — order details and status history

Protected routes require `Authorization: Bearer <access_token>`.

## Backend local setup

1. Install Python 3.12 or newer and PostgreSQL 16 (or use the SQLite development fallback).
2. Create and activate a virtual environment.
3. Install dependencies: `pip install -r requirements.txt`.
4. Copy `.env.example` to `.env`. Set a unique `DJANGO_SECRET_KEY`, database settings, and Razorpay **test** credentials.
5. Apply migrations: `python manage.py migrate`.
6. Create the first administrator: `python manage.py createsuperuser`.
7. Start the API: `python manage.py runserver 0.0.0.0:8000`.
8. Open `http://127.0.0.1:8000/admin/` and create products, SKUs, prices, units, images, and stock quantities.

The catalogue is public. Customer cart, wishlist, address, checkout, and order endpoints require a customer JWT.

## Flutter Android setup

1. Install the stable Flutter SDK and Android Studio with an Android SDK.
2. Open a terminal in the `mobile` directory.
3. Generate the Android runner files once: `flutter create . --platforms android`.
4. Install packages: `flutter pub get`.
5. Start Django on port 8000.
6. Run on the Android emulator:
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
7. For a physical Android phone, use the computer's reachable LAN address instead of `10.0.2.2`, and allow the phone to reach the development API. Use HTTPS for hosted environments.
8. Build a debug APK with `flutter build apk --debug`.

The local emulator URL uses HTTP. If Android blocks cleartext traffic, enable it only in the **debug** Android manifest/build configuration for local development. Do not enable cleartext traffic in a release build. The app uses Flutter secure storage for tokens; no Razorpay secret is stored in the mobile app.

## Razorpay test-mode setup

1. Create or use a Razorpay account and generate a **Test Mode** Key ID and Key Secret.
2. Set `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and a separate `RAZORPAY_WEBHOOK_SECRET` in the backend environment.
3. Configure a webhook endpoint at `https://<your-test-api-host>/api/v1/commerce/payments/razorpay/webhook/`.
4. Subscribe to `payment.captured` and `payment.failed` events and use the same webhook secret configured on the server.
5. The app opens Razorpay Standard Checkout with the server-created gateway order. The server verifies the checkout signature and fetches the payment from Razorpay to confirm captured status, order ID, amount, and INR currency before confirming an order.
6. A client callback alone never confirms an order. The signed webhook is independently validated and duplicate event IDs are ignored.

Use only Razorpay test credentials while validating. Do not put the Key Secret or webhook secret in Flutter, source control, or client-side build arguments.

## Automated checks

Backend:
```bash
pip install -r requirements.txt
python manage.py check
python manage.py migrate --noinput
python manage.py test
```

Flutter (from `mobile`):
```bash
flutter create . --platforms android
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions runs the Django checks/tests and Flutter analysis/test/debug-APK build on pushes and pull requests to `main`. A successful run must be visible in the repository Actions tab before treating the project as verified complete.

## Deployment outline

- Deploy Django behind an HTTPS reverse proxy with PostgreSQL and a production WSGI server such as Gunicorn.
- Set a strong secret key, `DJANGO_DEBUG=False`, exact `DJANGO_ALLOWED_HOSTS`, database credentials, Razorpay **live** credentials only after separate approval, and the webhook secret through the host's secret manager.
- Run migrations during release and collect Django admin static files with `python manage.py collectstatic --noinput`; serve the generated static directory through the web server.
- Enable HTTPS redirects, secure cookies, and HSTS only after TLS and proxy headers are correctly configured.
- Set the Flutter release API URL to the HTTPS API host and build/sign the Android release artifact.
- Configure monitoring, backups, payment reconciliation, cancellation/expiry/refund handling, incident response, and end-to-end payment tests before any production launch.

## Project status

Feature implementation is still under verification. The repository does not yet have a confirmed successful GitHub Actions result or a verified Android build. Do not treat the app as complete or production-ready until the automated checks and end-to-end test-mode payment flow have been verified.
