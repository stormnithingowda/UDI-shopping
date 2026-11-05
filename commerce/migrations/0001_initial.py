import django.core.validators
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalog", "0001_initial"),
    ]
    operations = [
        migrations.CreateModel(
            name="Address",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("full_name", models.CharField(max_length=120)),
                ("phone", models.CharField(max_length=20)),
                ("address_line1", models.CharField(max_length=255)),
                ("address_line2", models.CharField(blank=True, max_length=255)),
                ("city", models.CharField(max_length=100)),
                ("state", models.CharField(max_length=100)),
                ("postal_code", models.CharField(max_length=12)),
                ("is_default", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="delivery_addresses", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="Cart",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="shopping_cart", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="Order",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("status", models.CharField(choices=[("pending_payment", "Pending payment"), ("confirmed", "Confirmed"), ("processing", "Processing"), ("shipped", "Shipped"), ("delivered", "Delivered"), ("cancelled", "Cancelled"), ("payment_failed", "Payment failed")], default="pending_payment", max_length=24)),
                ("total_amount", models.DecimalField(decimal_places=2, max_digits=12)),
                ("currency", models.CharField(default="INR", max_length=3)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("address", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="orders", to="commerce.address")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="orders", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="CartItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("quantity", models.DecimalField(decimal_places=3, max_digits=12, validators=[django.core.validators.MinValueValidator(0.001)])),
                ("cart", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="items", to="commerce.cart")),
                ("product", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="catalog.product")),
            ],
        ),
        migrations.CreateModel(
            name="WishlistItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("product", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="catalog.product")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="wishlist_items", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="OrderItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("product_name", models.CharField(max_length=180)),
                ("sku", models.CharField(max_length=64)),
                ("unit_price", models.DecimalField(decimal_places=2, max_digits=10)),
                ("quantity", models.DecimalField(decimal_places=3, max_digits=12)),
                ("line_total", models.DecimalField(decimal_places=2, max_digits=12)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="items", to="commerce.order")),
                ("product", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to="catalog.product")),
            ],
        ),
        migrations.CreateModel(
            name="OrderStatusHistory",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("status", models.CharField(choices=[("pending_payment", "Pending payment"), ("confirmed", "Confirmed"), ("processing", "Processing"), ("shipped", "Shipped"), ("delivered", "Delivered"), ("cancelled", "Cancelled"), ("payment_failed", "Payment failed")], max_length=24)),
                ("note", models.CharField(blank=True, max_length=255)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="status_history", to="commerce.order")),
            ],
        ),
        migrations.AddConstraint(
            model_name="cartitem",
            constraint=models.UniqueConstraint(fields=("cart", "product"), name="unique_cart_product"),
        ),
        migrations.AddConstraint(
            model_name="wishlistitem",
            constraint=models.UniqueConstraint(fields=("user", "product"), name="unique_wishlist_product"),
        ),
    ]
