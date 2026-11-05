from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [("commerce", "0001_initial")]
    operations = [
        migrations.CreateModel(
            name="RazorpayPayment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("razorpay_order_id", models.CharField(max_length=100, unique=True)),
                ("razorpay_payment_id", models.CharField(blank=True, max_length=100, null=True, unique=True)),
                ("status", models.CharField(choices=[("created", "Created"), ("authorized", "Authorized"), ("captured", "Captured"), ("failed", "Failed")], default="created", max_length=20)),
                ("amount_paise", models.PositiveBigIntegerField()),
                ("currency", models.CharField(default="INR", max_length=3)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("order", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, related_name="payment", to="commerce.order")),
            ],
        ),
        migrations.CreateModel(
            name="RazorpayWebhookEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("event_id", models.CharField(max_length=150, unique=True)),
                ("event_type", models.CharField(max_length=80)),
                ("processed_at", models.DateTimeField(auto_now_add=True)),
            ],
        ),
    ]
