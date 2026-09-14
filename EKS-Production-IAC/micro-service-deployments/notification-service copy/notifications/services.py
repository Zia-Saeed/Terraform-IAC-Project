import logging

logger = logging.getLogger("notifications")


def send_email(to_user_id: int, subject: str, body: str) -> None:
    """Stubbed 'send'. In production this calls AWS SES / SendGrid.
    Kept as its own function so swapping providers only touches this file."""
    logger.info("EMAIL -> user_id=%s subject=%r body=%r", to_user_id, subject, body)
