from django.urls import path
from .auth_views import RegisterView
from .payment_views import CreateRazorpayOrderView, RazorpayWebhookView, VerifyRazorpayPaymentView
from .views import AddressListCreateView, CartItemDetailView, CartView, CheckoutView, OrderDetailView, OrderListView, WishlistMoveToCartView, WishlistView

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("cart/", CartView.as_view(), name="cart"),
    path("cart/items/<int:pk>/", CartItemDetailView.as_view(), name="cart-item-detail"),
    path("wishlist/", WishlistView.as_view(), name="wishlist"),
    path("wishlist/<int:pk>/move-to-cart/", WishlistMoveToCartView.as_view(), name="wishlist-move-to-cart"),
    path("addresses/", AddressListCreateView.as_view(), name="addresses"),
    path("checkout/", CheckoutView.as_view(), name="checkout"),
    path("orders/<int:order_id>/payment/create/", CreateRazorpayOrderView.as_view(), name="payment-create"),
    path("orders/<int:order_id>/payment/verify/", VerifyRazorpayPaymentView.as_view(), name="payment-verify"),
    path("payments/razorpay/webhook/", RazorpayWebhookView.as_view(), name="razorpay-webhook"),
    path("orders/", OrderListView.as_view(), name="orders"),
    path("orders/<int:pk>/", OrderDetailView.as_view(), name="order-detail"),
]
