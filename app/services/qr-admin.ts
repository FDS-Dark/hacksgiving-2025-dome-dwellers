import { API_BASE_URL } from '@/constants/config';

export interface QRCodeDetail {
  qr_code_id: number;
  code_token: string;
  species_id: number;
  location_id?: number | null;
  active: boolean;
  is_public: boolean;
  created_at: string;
  common_name: string | null;
  scientific_name: string;
  location_name?: string | null;
  scan_count: number;
  deep_link_url?: string;
}

export interface QRCodeInfo {
  id: number;
  code_token: string;
  species_id: number;
  location_id?: number | null;
  active: boolean;
  common_name?: string | null;
  scientific_name?: string | null;
  location_name?: string | null;
  created_at: string;
}

export interface QRCodeCreateRequest {
  species_id: number;
  location_id?: number | null;
}

export interface QRCodeBulkCreateRequest {
  species_ids: number[];
  location_ids?: (number | null)[];
}

export interface QRCodeBulkCreateResponse {
  created_count: number;
  qr_codes: QRCodeInfo[];
}

class QRAdminService {
  private baseUrl = `${API_BASE_URL}/admin/qr`;

  async getAllQRCodes(accessToken: string): Promise<QRCodeDetail[]> {
    const response = await fetch(`${this.baseUrl}/codes`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to fetch QR codes');
    }

    return response.json();
  }

  async createQRCode(
    speciesId: number,
    accessToken: string,
    locationId?: number | null
  ): Promise<QRCodeInfo> {
    const response = await fetch(`${this.baseUrl}/codes`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ 
        species_id: speciesId,
        location_id: locationId 
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to create QR code');
    }

    return response.json();
  }

  async bulkCreateQRCodes(
    speciesIds: number[],
    accessToken: string,
    locationIds?: (number | null)[]
  ): Promise<QRCodeBulkCreateResponse> {
    const response = await fetch(`${this.baseUrl}/codes/bulk`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ 
        species_ids: speciesIds,
        location_ids: locationIds 
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to create QR codes');
    }

    return response.json();
  }

  getQRCodeImageUrl(qrCodeId: number, accessToken: string): string {
    return `${this.baseUrl}/codes/${qrCodeId}/image?token=${accessToken}`;
  }

  getQRCodeImageWithLabelUrl(qrCodeId: number, accessToken: string): string {
    return `${this.baseUrl}/codes/${qrCodeId}/image-with-label?token=${accessToken}`;
  }

  async downloadQRCodeImage(qrCodeId: number, accessToken: string): Promise<Blob> {
    const response = await fetch(`${this.baseUrl}/codes/${qrCodeId}/image-with-label`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to download QR code image');
    }

    return response.blob();
  }

  async exportAllQRCodes(accessToken: string): Promise<Blob> {
    const response = await fetch(`${this.baseUrl}/codes/export-all`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to export QR codes');
    }

    return response.blob();
  }

  async activateQRCode(qrCodeId: number, accessToken: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/codes/${qrCodeId}/activate`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to activate QR code');
    }
  }

  async getQRCodeForSpecies(
    speciesId: number,
    accessToken: string
  ): Promise<QRCodeInfo | null> {
    const response = await fetch(`${this.baseUrl}/species/${speciesId}/code`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (response.status === 404) {
      return null;
    }

    if (!response.ok) {
      throw new Error('Failed to fetch QR code for species');
    }

    return response.json();
  }
}

export const qrAdminService = new QRAdminService();

