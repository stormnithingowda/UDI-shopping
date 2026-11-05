from rest_framework.generics import ListAPIView, RetrieveAPIView
from .models import Product
from .serializers import ProductSerializer

class ProductListView(ListAPIView):
    serializer_class = ProductSerializer
    queryset = Product.objects.filter(is_active=True).order_by("name")

class ProductDetailView(RetrieveAPIView):
    serializer_class = ProductSerializer
    queryset = Product.objects.filter(is_active=True)
    lookup_field = "slug"
