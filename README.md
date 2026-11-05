# UDI-shopping

UDI Shopping is an e-commerce application under development.

## Current backend foundation
- Django 5.2 and Django REST Framework
- PostgreSQL-ready configuration with SQLite fallback for local development
- Public product catalogue API
- JWT authentication endpoints
- Customer-owned cart and wishlist
- Customer delivery addresses
- Checkout creates a pending-payment order and reserves stock in a database transaction
- Order list, detail, and status history
- Django admin for product and commerce records

## API routes
- `POST /api/v1/commerce/register/` — create a customer account and receive JWT tokens
- `POST /api/v1/auth/token/` — obtain JWT access and refresh tokens (username/password)
- `POST /api/v1/auth/token/refresh/` — refresh access token
- `GET /api/v1/catalog/products/` — public product list
- `GET /api/v1/catalog/products/<slug>/` — public product details
- `GET|POST|DELETE /api/v1/commerce/cart/` — current user's cart
- `PATCH|DELETE /api/v1/commerce/cart/items/<id>/` — update or remove a cart item
- `GET|POST|DELETE /api/v1/commerce/wishlist/` — current user's wishlist
- `POST /api/v1/commerce/wishlist/<id>/move-to-cart/` — move a saved product into the cart
- `GET|POST /api/v1/commerce/addresses/` — current user's delivery addresses
- `POST /api/v1/commerce/checkout/` — create pending-payment order; JSON body: `{"address_id": 1}`
- `POST /api/v1/commerce/orders/<id>/payment/create/` — create a Razorpay payment order
- `POST /api/v1/commerce/orders/<id>/payment/verify/` — verify signature and captured payment with Razorpay
- `POST /api/v1/commerce/payments/razorpay/webhook/` — receive signed and deduplicated Razorpay events
- `GET /api/v1/commerce/orders/` — current user's orders
- `GET /api/v1/commerce/orders/<id>/` — current user's order details and status history

Protected routes require `Authorization: Bearer <access_token>`.

## Local setup
1. Create and activate a Python virtual environment.
2. Install dependencies: `pip install -r requirements.txt`.
3. Copy `.env.example` to `.env` and configure database values if using PostgreSQL.
4. Run migrations: `python manage.py migrate`.
5. Create an admin account: `python manage.py createsuperuser`.
6. Start the API: `python manage.py runserver`.

## Important payment note
Checkout creates an order with `pending_payment` status and reserves inventory. The Razorpay integration includes server-side order creation, signature verification, a server-side captured-status/amount check, signed webhook validation, event-ID deduplication, and stock release on a verified `payment.failed` webhook. Configure the three Razorpay variables in `.env` with TEST credentials. This is a test-mode foundation, not production approval: live deployment still requires end-to-end gateway testing, cancellation/expiry handling, monitoring, HTTPS, secret management, and a successful CI run.

## Project status
Backend foundation and initial commerce endpoints are committed. Automated tests are included. GitHub Actions runs the Django test suite on pushes and pull requests; passing status must be confirmed in the repository Actions tab.
