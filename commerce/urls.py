from django.urls import path
from .views import AddressListCreateView, CartView, CheckoutView, OrderDetailView, OrderListView, WishlistView

urlpatterns = [
    path("cart/", CartView.as_view(), name="cart"),
    path("wishlist/", WishlistView.as_view(), name="wishlist"),
    path("addresses/", AddressListCreateView.as_view(), name="addresses"),
    path("checkout/", CheckoutView.as_view(), name="checkout"),
    path("orders/", OrderListView.as_view(), name="orders"),
    path("orders/<int:pk>/", OrderDetailView.as_view(), name="order-detail"),
]
