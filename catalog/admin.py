from django.contrib import admin
from .models import Product

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "sku", "price", "stock_quantity", "unit", "is_active")
    list_filter = ("is_active", "unit")
    search_fields = ("name", "sku")
    prepopulated_fields = {"slug": ("name",)}
