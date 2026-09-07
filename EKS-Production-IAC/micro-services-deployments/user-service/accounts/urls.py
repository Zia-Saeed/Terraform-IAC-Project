from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import LoginView, ProfileView, RegisterView, UserDetailView, health

urlpatterns = [
    path("health/", health),
    path("api/users/register/", RegisterView.as_view(), name="register"),
    path("api/users/login/", LoginView.as_view(), name="login"),
    path("api/users/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/users/me/", ProfileView.as_view(), name="profile"),
    path("api/users/<int:user_id>/", UserDetailView.as_view(), name="user-detail"),
]
