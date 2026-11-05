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
- `POST /api/v1/auth/token/` — obtain JWT access and refresh tokens (username/password)
- `POST /api/v1/auth/token/refresh/` — refresh access token
- `GET /api/v1/catalog/products/` — public product list
- `GET /api/v1/catalog/products/<slug>/` — public product details
- `GET|POST|DELETE /api/v1/commerce/cart/` — current user's cart
- `GET|POST|DELETE /api/v1/commerce/wishlist/` — current user's wishlist
- `GET|POST /api/v1/commerce/addresses/` — current user's delivery addresses
- `POST /api/v1/commerce/checkout/` — create pending-payment order; JSON body: `{"address_id": 1}`
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
Checkout currently creates an order with `pending_payment` status and reserves inventory. It does not mark an order paid. Razorpay order creation, server-side signature verification, verified capture checks, webhook idempotency, and stock release on payment failure/cancellation are not implemented yet. Do not use this checkout flow for live sales until those payment safeguards are completed and tested.

## Project status
Backend foundation and initial commerce endpoints are committed. Automated tests are included but have not yet been executed in a live environment.
