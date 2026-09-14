from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.models import TokenUser


class StatelessJWTAuthentication(JWTAuthentication):
    """Trusts the signature on tokens issued by user-service without
    querying a local User table (order-service's DB has none)."""

    def get_user(self, validated_token):
        return TokenUser(validated_token)
