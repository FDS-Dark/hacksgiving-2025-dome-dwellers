import { API_BASE_URL } from '@/constants/config';
import { Announcement, AnnouncementCreate, AnnouncementUpdate } from '@/types/announcements';

const API_URL = `${API_BASE_URL}/announcements`;

export const announcementsService = {
  async getAll(token: string): Promise<Announcement[]> {
    const response = await fetch(API_URL, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error('Failed to fetch announcements');
    }

    return response.json();
  },

  async create(token: string, announcement: AnnouncementCreate): Promise<Announcement> {
    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(announcement),
    });

    if (!response.ok) {
      throw new Error('Failed to create announcement');
    }

    return response.json();
  },

  async update(token: string, id: number, announcement: AnnouncementUpdate): Promise<void> {
    const response = await fetch(`${API_URL}/${id}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(announcement),
    });

    if (!response.ok) {
      throw new Error('Failed to update announcement');
    }
  },

  async delete(token: string, id: number): Promise<void> {
    const response = await fetch(`${API_URL}/${id}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error('Failed to delete announcement');
    }
  },
};

