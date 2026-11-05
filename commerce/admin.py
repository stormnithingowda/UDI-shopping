from django.contrib import admin
from .models import Address, Cart, CartItem, Order, OrderItem, OrderStatusHistory, WishlistItem

admin.site.register([Cart, CartItem, WishlistItem, Address, Order, OrderItem, OrderStatusHistory])

from .models import RazorpayPayment, RazorpayWebhookEvent
admin.site.register([RazorpayPayment, RazorpayWebhookEvent])
