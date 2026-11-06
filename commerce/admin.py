from django.contrib import admin
from django.db import transaction

from .models import (
    Address,
    Cart,
    CartItem,
    Order,
    OrderItem,
    OrderStatusHistory,
    RazorpayPayment,
    RazorpayWebhookEvent,
    WishlistItem,
)


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    can_delete = False
    readonly_fields = (
        "product",
        "product_name",
        "sku",
        "unit_price",
        "quantity",
        "line_total",
    )

    def has_add_permission(self, request, obj=None):
        return False


class OrderStatusHistoryInline(admin.TabularInline):
    model = OrderStatusHistory
    extra = 0
    can_delete = False
    readonly_fields = ("status", "note", "created_at")

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "status", "total_amount", "currency", "created_at")
    list_filter = ("status", "currency", "created_at")
    search_fields = ("id", "user__username", "user__email")
    readonly_fields = ("user", "address", "status", "total_amount", "currency", "created_at", "updated_at")
    inlines = (OrderItemInline, OrderStatusHistoryInline)
    actions = ("mark_processing", "mark_shipped", "mark_delivered")

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def _advance_status(self, request, queryset, target_status, allowed_statuses):
        updated = 0
        for selected in queryset:
            with transaction.atomic():
                order = Order.objects.select_for_update().filter(pk=selected.pk).first()
                if order is None or order.status not in allowed_statuses:
                    continue
                order.status = target_status
                order.save(update_fields=("status", "updated_at"))
                OrderStatusHistory.objects.create(
                    order=order,
                    status=target_status,
                    note="Order status updated by staff in Django admin.",
                )
                updated += 1
        self.message_user(request, f"Updated {updated} order(s).")

    @admin.action(description="Move confirmed orders to processing")
    def mark_processing(self, request, queryset):
        self._advance_status(
            request,
            queryset,
            Order.Status.PROCESSING,
            (Order.Status.CONFIRMED,),
        )

    @admin.action(description="Mark processing orders as shipped")
    def mark_shipped(self, request, queryset):
        self._advance_status(
            request,
            queryset,
            Order.Status.SHIPPED,
            (Order.Status.PROCESSING,),
        )

    @admin.action(description="Mark shipped orders as delivered")
    def mark_delivered(self, request, queryset):
        self._advance_status(
            request,
            queryset,
            Order.Status.DELIVERED,
            (Order.Status.SHIPPED,),
        )


class ReadOnlyAuditAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_view_permission(self, request, obj=None):
        opts = self.opts
        return request.user.has_perm(f"{opts.app_label}.view_{opts.model_name}") or request.user.has_perm(
            f"{opts.app_label}.change_{opts.model_name}"
        )

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(RazorpayPayment)
class RazorpayPaymentAdmin(ReadOnlyAuditAdmin):
    list_display = ("order", "razorpay_order_id", "razorpay_payment_id", "status", "amount_paise", "currency")
    list_filter = ("status", "currency")
    search_fields = ("razorpay_order_id", "razorpay_payment_id", "order__id")
    readonly_fields = (
        "order",
        "razorpay_order_id",
        "razorpay_payment_id",
        "status",
        "amount_paise",
        "currency",
        "created_at",
        "updated_at",
    )


@admin.register(RazorpayWebhookEvent)
class RazorpayWebhookEventAdmin(ReadOnlyAuditAdmin):
    list_display = ("event_id", "event_type", "processed_at")
    list_filter = ("event_type", "processed_at")
    search_fields = ("event_id", "event_type")
    readonly_fields = ("event_id", "event_type", "processed_at")


@admin.register(OrderItem)
class OrderItemAdmin(ReadOnlyAuditAdmin):
    list_display = ("order", "product_name", "sku", "quantity", "unit_price", "line_total")
    search_fields = ("order__id", "product_name", "sku")
    readonly_fields = ("order", "product", "product_name", "sku", "unit_price", "quantity", "line_total")


@admin.register(OrderStatusHistory)
class OrderStatusHistoryAdmin(ReadOnlyAuditAdmin):
    list_display = ("order", "status", "note", "created_at")
    list_filter = ("status", "created_at")
    search_fields = ("order__id", "note")
    readonly_fields = ("order", "status", "note", "created_at")


admin.site.register([Cart, CartItem, WishlistItem, Address])
