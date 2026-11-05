from rest_framework import serializers
from catalog.models import Product
from .models import Address, Cart, CartItem, Order, OrderItem, WishlistItem

class ProductBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = ("id", "name", "slug", "sku", "price", "unit", "image_url")

class CartItemSerializer(serializers.ModelSerializer):
    product = ProductBriefSerializer(read_only=True)
    class Meta:
        model = CartItem
        fields = ("id", "product", "quantity")

class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        exclude = ("user",)

class WishlistSerializer(serializers.ModelSerializer):
    product = ProductBriefSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(source="product", queryset=Product.objects.filter(is_active=True), write_only=True)
    class Meta:
        model = WishlistItem
        fields = ("id", "product", "product_id", "created_at")
        read_only_fields = ("id", "product", "created_at")

class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ("product_name", "sku", "unit_price", "quantity", "line_total")

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    class Meta:
        model = Order
        fields = ("id", "status", "total_amount", "currency", "created_at", "items")
