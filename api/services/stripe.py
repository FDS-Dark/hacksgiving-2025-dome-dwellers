import stripe
from typing import Dict, Any, Optional
from databridge.postgres_databridge import PostgresDatabridge
from structlog import get_logger
from settings import config

logger = get_logger()


class StripeService:
    """Service for handling Stripe payment operations"""

    def __init__(self, databridge: PostgresDatabridge):
        self.databridge = databridge
        # Initialize Stripe with API key from settings
        stripe.api_key = config.stripe.api_key
        
    async def create_checkout_session(
        self,
        line_items: list[Dict[str, Any]],
        success_url: str,
        cancel_url: str,
        mode: str = "payment",
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Create a Stripe Checkout session
        
        Args:
            line_items: List of items to purchase
            success_url: URL to redirect on successful payment
            cancel_url: URL to redirect on cancelled payment
            mode: Checkout mode (payment, subscription, setup)
            metadata: Additional metadata
            
        Returns:
            Checkout session details including url
        """
        try:
            session = stripe.checkout.Session.create(
                line_items=line_items,
                mode=mode,
                success_url=success_url,
                cancel_url=cancel_url,
                metadata=metadata or {},
            )
            
            logger.info(f"Created checkout session: {session.id}")
            
            return {
                "id": session.id,
                "url": session.url,
                "status": session.status,
            }
        except stripe.StripeError as e:
            logger.error(f"Stripe error creating checkout session: {str(e)}")
            raise Exception(f"Failed to create checkout session: {str(e)}")
    
    async def create_ticket_checkout(
        self,
        ticket_type: str,
        quantity: int,
        success_url: str,
        cancel_url: str
    ) -> Dict[str, Any]:
        """
        Create a checkout session for ticket purchases
        
        Args:
            ticket_type: Type of ticket (general, vip, family)
            quantity: Number of tickets
            success_url: Success redirect URL
            cancel_url: Cancel redirect URL
            
        Returns:
            Checkout session details
        """
        # Define ticket prices (in cents)
        ticket_prices = {
            "general": 900,        # $9.00 - General Admission
            "season_pass": 5000,   # $50.00 - Season Pass
        }
        
        if ticket_type not in ticket_prices:
            raise ValueError(f"Invalid ticket type: {ticket_type}")
        
        line_items = [{
            "price_data": {
                "currency": "usd",
                "product_data": {
                    "name": f"{ticket_type.capitalize()} Ticket",
                    "description": f"Admission ticket - {ticket_type.capitalize()}",
                },
                "unit_amount": ticket_prices[ticket_type],
            },
            "quantity": quantity,
        }]
        
        metadata = {
            "type": "ticket",
            "ticket_type": ticket_type,
            "quantity": str(quantity),
        }
        
        return await self.create_checkout_session(
            line_items=line_items,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=metadata
        )
    
    async def create_donation_checkout(
        self,
        amount: int,
        success_url: str,
        cancel_url: str,
        donor_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create a checkout session for donations
        
        Args:
            amount: Donation amount in cents
            success_url: Success redirect URL
            cancel_url: Cancel redirect URL
            donor_name: Optional donor name
            
        Returns:
            Checkout session details
        """
        line_items = [{
            "price_data": {
                "currency": "usd",
                "product_data": {
                    "name": "Donation",
                    "description": "Thank you for your generous donation!",
                },
                "unit_amount": amount,
            },
            "quantity": 1,
        }]
        
        metadata = {
            "type": "donation",
            "amount": str(amount),
        }
        
        if donor_name:
            metadata["donor_name"] = donor_name
        
        return await self.create_checkout_session(
            line_items=line_items,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=metadata
        )
    
    async def create_gift_shop_checkout(
        self,
        items: list[Dict[str, Any]],
        success_url: str,
        cancel_url: str
    ) -> Dict[str, Any]:
        """
        Create a checkout session for gift shop purchases
        
        Args:
            items: List of items with name, price, quantity
            success_url: Success redirect URL
            cancel_url: Cancel redirect URL
            
        Returns:
            Checkout session details
        """
        line_items = []
        for item in items:
            line_items.append({
                "price_data": {
                    "currency": "usd",
                    "product_data": {
                        "name": item["name"],
                        "description": item.get("description", ""),
                        "images": item.get("images", []),
                    },
                    "unit_amount": item["price"],
                },
                "quantity": item["quantity"],
            })
        
        metadata = {
            "type": "gift_shop",
            "item_count": str(len(items)),
        }
        
        return await self.create_checkout_session(
            line_items=line_items,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=metadata
        )
    
    async def retrieve_session(self, session_id: str) -> Dict[str, Any]:
        """
        Retrieve a checkout session by ID
        
        Args:
            session_id: The checkout session ID
            
        Returns:
            Session details
        """
        try:
            session = stripe.checkout.Session.retrieve(session_id)
            return {
                "id": session.id,
                "status": session.status,
                "payment_status": session.payment_status,
                "amount_total": session.amount_total,
                "metadata": session.metadata,
            }
        except stripe.StripeError as e:
            logger.error(f"Stripe error retrieving session: {str(e)}")
            raise Exception(f"Failed to retrieve session: {str(e)}")

