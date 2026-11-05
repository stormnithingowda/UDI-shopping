from rest_framework import serializers
from .models import Product

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = (
            "id", "name", "slug", "description", "sku", "price",
            "stock_quantity", "unit", "image_url", "is_active",
            "created_at", "updated_at",
        )
        read_only_fields = fields
