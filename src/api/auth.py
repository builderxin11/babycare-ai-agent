"""JWT token validation for Cognito authentication.

Validates Bearer tokens from the Authorization header against AWS Cognito.
"""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

# Cognito configuration (from environment or defaults)
COGNITO_REGION = os.getenv("AWS_REGION", "us-west-2")
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "us-west-2_74ZgBPACM")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID", "536dddrl7ju962f8bb5qe5b4rn")

# JWKS URL for token verification
COGNITO_ISSUER = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"
JWKS_URL = f"{COGNITO_ISSUER}/.well-known/jwks.json"

security = HTTPBearer(auto_error=False)


@lru_cache(maxsize=1)
def get_jwks() -> dict:
    """Fetch and cache Cognito JWKS (JSON Web Key Set)."""
    response = httpx.get(JWKS_URL, timeout=10)
    response.raise_for_status()
    return response.json()


def get_signing_key(token: str) -> dict:
    """Get the signing key for a JWT token from JWKS."""
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")

    jwks = get_jwks()
    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return key

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Unable to find signing key",
    )


class AuthenticatedUser:
    """Represents an authenticated user from Cognito."""

    def __init__(self, sub: str, email: str | None = None):
        self.sub = sub  # Cognito user ID
        self.email = email

    @property
    def user_id(self) -> str:
        return self.sub


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> AuthenticatedUser | None:
    """
    Validate JWT token and return current user.

    Returns None if no token provided (allows unauthenticated access for MVP).
    In production, you might want to require authentication.
    """
    if credentials is None:
        return None

    token = credentials.credentials

    try:
        signing_key = get_signing_key(token)

        payload = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            audience=COGNITO_CLIENT_ID,
            issuer=COGNITO_ISSUER,
            options={"verify_at_hash": False},
        )

        user_sub = payload.get("sub")
        email = payload.get("email")

        if not user_sub:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing sub claim",
            )

        return AuthenticatedUser(sub=user_sub, email=email)

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}",
        ) from e
    except httpx.RequestError as e:
        # If we can't fetch JWKS, allow the request for MVP
        # In production, you might want to fail closed
        return None


async def require_auth(
    user: Annotated[AuthenticatedUser | None, Depends(get_current_user)],
) -> AuthenticatedUser:
    """Require authentication - raises 401 if not authenticated."""
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
