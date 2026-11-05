from django.contrib import admin
from .models import Address, Cart, CartItem, Order, OrderItem, OrderStatusHistory, WishlistItem

admin.site.register([Cart, CartItem, WishlistItem, Address, Order, OrderItem, OrderStatusHistory])
