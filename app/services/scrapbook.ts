import { API_BASE_URL } from '@/constants/config';
import {
  CollectibleCatalogEntry,
  DiscoveryDetails,
  DiscoveryResponse,
  CollectionStats,
  QRCodeInfo,
} from '@/types/scrapbook';

export const scrapbookService = {
  async getCatalog(token: string): Promise<CollectibleCatalogEntry[]> {
    const url = `${API_BASE_URL}/scrapbook/catalog`;
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch catalog: ${response.statusText}`);
    }
    
    return response.json();
  },

  async scanQRCode(token: string, qrToken: string): Promise<DiscoveryResponse> {
    const url = `${API_BASE_URL}/scrapbook/scan`;
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ qr_token: qrToken }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to scan QR code: ${response.statusText}`);
    }
    
    return response.json();
  },

  async getDiscoveryDetails(token: string, catalogEntryId: number): Promise<DiscoveryDetails> {
    const url = `${API_BASE_URL}/scrapbook/discovery/${catalogEntryId}`;
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch discovery: ${response.statusText}`);
    }
    
    return response.json();
  },

  async updateNotes(token: string, discoveryId: number, notes: string): Promise<void> {
    const url = `${API_BASE_URL}/scrapbook/discovery/${discoveryId}/notes`;
    
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ notes }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to update notes: ${response.statusText}`);
    }
  },

  async toggleFavorite(token: string, discoveryId: number): Promise<boolean> {
    const url = `${API_BASE_URL}/scrapbook/discovery/${discoveryId}/favorite`;
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to toggle favorite: ${response.statusText}`);
    }
    
    const data = await response.json();
    return data.is_favorite;
  },

  async getCollectionStats(token: string): Promise<CollectionStats> {
    const url = `${API_BASE_URL}/scrapbook/stats`;
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!response.ok) {
      throw new Error(`Failed to fetch stats: ${response.statusText}`);
    }
    
    return response.json();
  },

  async getQRInfo(qrToken: string): Promise<QRCodeInfo> {
    const url = `${API_BASE_URL}/scrapbook/qr/${qrToken}`;
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch QR info: ${response.statusText}`);
    }
    
    return response.json();
  },
};

