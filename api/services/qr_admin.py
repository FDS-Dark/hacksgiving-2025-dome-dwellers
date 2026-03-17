from typing import List, Optional
import io
import zipfile
from databridge.scrapbook_databridge import ScrapbookDatabridge
from models.scrapbook import (
    QRCodeDetail,
    QRCodeInfo,
    QRCodeBulkCreateResponse,
)
from settings import config


class QRAdminService:
    def __init__(self, databridge: ScrapbookDatabridge):
        self.databridge = databridge
        self.base_url = self._get_base_url()
    
    def _get_base_url(self) -> str:
        """
        Get the base URL for QR code deep links.
        Uses Tailscale IP if configured, otherwise localhost.
        """
        if config.tailscale.ip:
            return f"exp://{config.tailscale.ip}:8081"
        return "exp://localhost:8081"
    
    def _generate_deep_link(self, qr_token: str) -> str:
        """Generate deep link URL for QR code scanning"""
        return f"{self.base_url}/--/scan?qr={qr_token}"
    
    async def get_all_qr_codes(self) -> List[QRCodeDetail]:
        """Get all QR codes with detailed information"""
        qr_codes = await self.databridge.get_all_qr_codes()
        
        result = []
        for qr in qr_codes:
            # Map plant_species_id from database to species_id for API
            if "plant_species_id" in qr:
                qr["species_id"] = qr.pop("plant_species_id")
            
            deep_link = self._generate_deep_link(qr["code_token"])
            result.append(
                QRCodeDetail(
                    **qr,
                    deep_link_url=deep_link
                )
            )
        
        return result
    
    async def create_qr_code(self, species_id: int, location_id: Optional[int] = None) -> QRCodeInfo:
        """Create a new QR code for a plant species"""
        qr_data = await self.databridge.create_qr_code(species_id, location_id)
        # Map plant_species_id from database to species_id for API
        if "plant_species_id" in qr_data:
            qr_data["species_id"] = qr_data.pop("plant_species_id")
        return QRCodeInfo(**qr_data)
    
    async def bulk_create_qr_codes(self, species_ids: List[int], location_ids: Optional[List[Optional[int]]] = None) -> QRCodeBulkCreateResponse:
        """Bulk create QR codes for multiple plant species"""
        if location_ids is None:
            location_ids = [None] * len(species_ids)
        
        qr_codes = await self.databridge.bulk_create_qr_codes(species_ids, location_ids)
        
        # Map plant_species_id from database to species_id for API
        qr_code_list = []
        for qr in qr_codes:
            if "plant_species_id" in qr:
                qr["species_id"] = qr.pop("plant_species_id")
            qr_code_list.append(QRCodeInfo(**qr))
        
        return QRCodeBulkCreateResponse(
            created_count=len(qr_code_list),
            qr_codes=qr_code_list
        )
    
    async def deactivate_qr_code(self, qr_code_id: int) -> bool:
        """Deactivate a QR code"""
        return await self.databridge.deactivate_qr_code(qr_code_id)
    
    async def activate_qr_code(self, qr_code_id: int) -> bool:
        """Activate a QR code"""
        return await self.databridge.activate_qr_code(qr_code_id)
    
    async def get_qr_code_by_species(self, species_id: int, location_id: Optional[int] = None) -> Optional[QRCodeInfo]:
        """Get QR code for a specific plant species and location"""
        qr_codes = await self.databridge.get_qr_codes_by_species_and_location(species_id, location_id)
        if qr_codes:
            qr_code = qr_codes[0]  # Get the first matching QR code
            # Map plant_species_id from database to species_id for API
            if "plant_species_id" in qr_code:
                qr_code["species_id"] = qr_code.pop("plant_species_id")
            return QRCodeInfo(**qr_code)
        return None
    
    async def generate_qr_code_image(self, qr_code_id: int) -> Optional[bytes]:
        """
        Generate a QR code image for download.
        Returns PNG image bytes.
        """
        qr_details = await self.databridge.get_qr_code_by_id(qr_code_id)
        if not qr_details:
            return None
        
        deep_link = self._generate_deep_link(qr_details["code_token"])
        
        try:
            import qrcode
            from PIL import Image
            
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(deep_link)
            qr.make(fit=True)
            
            img = qr.make_image(fill_color="black", back_color="white")
            
            buf = io.BytesIO()
            img.save(buf, format='PNG')
            buf.seek(0)
            
            return buf.getvalue()
        except ImportError:
            raise Exception("qrcode and PIL libraries are required for QR code generation")
    
    async def generate_qr_code_image_with_label(self, qr_code_id: int) -> Optional[bytes]:
        """
        Generate a QR code image with plant information label.
        Returns PNG image bytes.
        """
        qr_details = await self.databridge.get_qr_code_details(qr_code_id)
        if not qr_details:
            return None
        
        deep_link = self._generate_deep_link(qr_details["code_token"])
        
        try:
            import qrcode
            from PIL import Image, ImageDraw, ImageFont
            
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(deep_link)
            qr.make(fit=True)
            
            qr_img = qr.make_image(fill_color="black", back_color="white")
            # Convert to RGB if needed
            if qr_img.mode != 'RGB':
                qr_img = qr_img.convert('RGB')
            
            qr_width, qr_height = qr_img.size
            
            label_height = 120
            total_height = qr_height + label_height
            
            final_img = Image.new('RGB', (qr_width, total_height), 'white')
            final_img.paste(qr_img, (0, 0))
            
            draw = ImageDraw.Draw(final_img)
            
            try:
                font_large = ImageFont.truetype("arial.ttf", 20)
                font_small = ImageFont.truetype("arial.ttf", 14)
            except:
                font_large = ImageFont.load_default()
                font_small = ImageFont.load_default()
            
            common_name = qr_details.get("common_name", "Unknown Plant")
            scientific_name = qr_details.get("scientific_name", "")
            accession = qr_details.get("accession_number", "")
            
            y_offset = qr_height + 10
            
            if common_name:
                draw.text((qr_width // 2, y_offset), common_name, font=font_large, fill="black", anchor="mt")
                y_offset += 30
            
            if scientific_name:
                draw.text((qr_width // 2, y_offset), scientific_name, font=font_small, fill="gray", anchor="mt")
                y_offset += 25
            
            if accession:
                draw.text((qr_width // 2, y_offset), f"Acc: {accession}", font=font_small, fill="gray", anchor="mt")
            
            buf = io.BytesIO()
            final_img.save(buf, format='PNG')
            buf.seek(0)
            
            return buf.getvalue()
        except ImportError:
            raise Exception("qrcode and PIL libraries are required for QR code generation")
    
    async def export_all_qr_codes(self) -> bytes:
        """
        Export all QR codes as a ZIP file.
        Each QR code is saved as a labeled PNG image.
        """
        qr_codes = await self.databridge.get_all_qr_codes()
        
        zip_buffer = io.BytesIO()
        
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            for qr in qr_codes:
                qr_code_id = qr["qr_code_id"]
                common_name = qr.get("common_name", "unknown")
                accession = qr.get("accession_number", qr_code_id)
                
                safe_name = "".join(c for c in common_name if c.isalnum() or c in (' ', '-', '_')).strip()
                filename = f"{safe_name}_{accession}.png"
                
                image_bytes = await self.generate_qr_code_image_with_label(qr_code_id)
                
                if image_bytes:
                    zip_file.writestr(filename, image_bytes)
        
        zip_buffer.seek(0)
        return zip_buffer.getvalue()

