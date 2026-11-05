from decimal import Decimal, ROUND_HALF_UP
from django.db import transaction
from django.db.models import F
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from catalog.models import Product
from .models import Address, Cart, CartItem, Order, OrderItem, OrderStatusHistory, WishlistItem
from .serializers import AddressSerializer, CartItemSerializer, OrderSerializer, WishlistSerializer

class CartView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        cart, _ = Cart.objects.get_or_create(user=request.user)
        items = CartItem.objects.filter(cart=cart).select_related("product")
        total = sum((i.product.price * i.quantity for i in items), Decimal("0.00")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        return Response({"items": CartItemSerializer(items, many=True).data, "total": total})

    def post(self, request):
        product = get_object_or_404(Product, pk=request.data.get("product_id"), is_active=True)
        try:
            quantity = Decimal(str(request.data.get("quantity", "1")))
        except Exception:
            return Response({"detail": "Quantity must be a valid decimal."}, status=400)
        if not quantity.is_finite() or quantity <= 0 or quantity.as_tuple().exponent < -3:
            return Response({"detail": "Quantity must be positive and have at most 3 decimal places."}, status=400)
        if quantity > product.stock_quantity:
            return Response({"detail": "Requested quantity is not available."}, status=400)
        cart, _ = Cart.objects.get_or_create(user=request.user)
        item, created = CartItem.objects.get_or_create(cart=cart, product=product, defaults={"quantity": quantity})
        if not created:
            new_quantity = item.quantity + quantity
            if new_quantity > product.stock_quantity:
                return Response({"detail": "Requested quantity exceeds available stock."}, status=400)
            item.quantity = new_quantity
            item.save(update_fields=["quantity"])
        return Response(CartItemSerializer(item).data, status=status.HTTP_201_CREATED if created else 200)

    def delete(self, request):
        cart = Cart.objects.filter(user=request.user).first()
        if cart:
            CartItem.objects.filter(cart=cart, pk=request.data.get("item_id")).delete()
        return Response(status=204)

class WishlistView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        items = WishlistItem.objects.filter(user=request.user).select_related("product")
        return Response(WishlistSerializer(items, many=True).data)
    def post(self, request):
        serializer = WishlistSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        item, _ = WishlistItem.objects.get_or_create(user=request.user, product=serializer.validated_data["product"])
        return Response(WishlistSerializer(item).data, status=201)
    def delete(self, request):
        WishlistItem.objects.filter(user=request.user, pk=request.data.get("item_id")).delete()
        return Response(status=204)

class AddressListCreateView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        return Response(AddressSerializer(Address.objects.filter(user=request.user), many=True).data)
    def post(self, request):
        serializer = AddressSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        address = serializer.save(user=request.user)
        return Response(AddressSerializer(address).data, status=201)

class CheckoutView(APIView):
    permission_classes = [IsAuthenticated]
    @transaction.atomic
    def post(self, request):
        address = get_object_or_404(Address, pk=request.data.get("address_id"), user=request.user)
        cart = Cart.objects.filter(user=request.user).first()
        if not cart:
            return Response({"detail": "Your cart is empty."}, status=400)
        items = list(CartItem.objects.filter(cart=cart).select_related("product").order_by("product_id"))
        if not items:
            return Response({"detail": "Your cart is empty."}, status=400)
        product_ids = [item.product_id for item in items]
        locked_products = {p.id: p for p in Product.objects.select_for_update().filter(id__in=product_ids, is_active=True)}
        total = Decimal("0.00")
        for item in items:
            product = locked_products.get(item.product_id)
            if not product or item.quantity > product.stock_quantity:
                return Response({"detail": f"Insufficient stock for {item.product.name}."}, status=400)
            total += (product.price * item.quantity).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        order = Order.objects.create(user=request.user, address=address, total_amount=total)
        for item in items:
            product = locked_products[item.product_id]
            line_total = (product.price * item.quantity).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            OrderItem.objects.create(
                order=order, product=product, product_name=product.name, sku=product.sku,
                unit_price=product.price, quantity=item.quantity, line_total=line_total,
            )
            Product.objects.filter(pk=product.pk).update(stock_quantity=F("stock_quantity") - item.quantity)
        OrderStatusHistory.objects.create(order=order, status=Order.Status.PENDING_PAYMENT, note="Order created; awaiting verified payment.")
        CartItem.objects.filter(cart=cart).delete()
        return Response(OrderSerializer(order).data, status=201)

class OrderListView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        orders = Order.objects.filter(user=request.user).prefetch_related("items").order_by("-created_at")
        return Response(OrderSerializer(orders, many=True).data)

class OrderDetailView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request, pk):
        order = get_object_or_404(Order.objects.prefetch_related("items", "status_history"), pk=pk, user=request.user)
        data = OrderSerializer(order).data
        data["status_history"] = [{"status": h.status, "note": h.note, "created_at": h.created_at} for h in order.status_history.all()]
        return Response(data)


class CartItemDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        item = get_object_or_404(
            CartItem.objects.select_related("product", "cart"),
            pk=pk, cart__user=request.user
        )
        try:
            quantity = Decimal(str(request.data.get("quantity")))
        except Exception:
            return Response({"detail": "Quantity must be a valid decimal."}, status=400)
        if not quantity.is_finite() or quantity <= 0 or quantity.as_tuple().exponent < -3:
            return Response({"detail": "Quantity must be positive and have at most 3 decimal places."}, status=400)
        if quantity > item.product.stock_quantity:
            return Response({"detail": "Requested quantity is not available."}, status=400)
        item.quantity = quantity
        item.save(update_fields=["quantity"])
        return Response(CartItemSerializer(item).data)

    def delete(self, request, pk):
        item = get_object_or_404(CartItem, pk=pk, cart__user=request.user)
        item.delete()
        return Response(status=204)


class WishlistMoveToCartView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        saved = get_object_or_404(
            WishlistItem.objects.select_related("product"), pk=pk, user=request.user
        )
        product = saved.product
        if not product.is_active:
            return Response({"detail": "This product is no longer available."}, status=400)
        try:
            quantity = Decimal(str(request.data.get("quantity", "1")))
        except Exception:
            return Response({"detail": "Quantity must be a valid decimal."}, status=400)
        if not quantity.is_finite() or quantity <= 0 or quantity.as_tuple().exponent < -3:
            return Response({"detail": "Quantity must be positive and have at most 3 decimal places."}, status=400)
        cart, _ = Cart.objects.get_or_create(user=request.user)
        item = CartItem.objects.filter(cart=cart, product=product).first()
        resulting_quantity = quantity + (item.quantity if item else Decimal("0"))
        if resulting_quantity > product.stock_quantity:
            return Response({"detail": "Requested quantity exceeds available stock."}, status=400)
        if item:
            item.quantity = resulting_quantity
            item.save(update_fields=["quantity"])
            created = False
        else:
            item = CartItem.objects.create(cart=cart, product=product, quantity=quantity)
            created = True
        return Response(CartItemSerializer(item).data, status=201 if created else 200)
