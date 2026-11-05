from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny
from .models import Product
from .serializers import ProductSerializer

class ProductListView(ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = ProductSerializer
    queryset = Product.objects.filter(is_active=True).order_by("name")

class ProductDetailView(RetrieveAPIView):
    permission_classes = [AllowAny]
    serializer_class = ProductSerializer
    queryset = Product.objects.filter(is_active=True)
    lookup_field = "slug"
