from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.models import TokenUser


class StatelessJWTAuthentication(JWTAuthentication):
    """Verifies the JWT signature/expiry (using the shared JWT_SECRET_KEY)
    but never touches this service's own database for the user record,
    since the User table lives only in user-service's database."""

    def get_user(self, validated_token):
        return TokenUser(validated_token)
