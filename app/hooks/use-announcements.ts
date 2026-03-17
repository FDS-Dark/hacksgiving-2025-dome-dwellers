import { useState, useEffect, useCallback } from 'react';
import { useAuth0 } from '@/components/Auth0Provider';
import { announcementsService } from '@/services/announcements';
import { Announcement, AnnouncementCreate, AnnouncementUpdate } from '@/types/announcements';

export function useAnnouncements() {
  const { accessToken, isAuthenticated } = useAuth0();
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAnnouncements = useCallback(async () => {
    if (!isAuthenticated || !accessToken) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const data = await announcementsService.getAll(accessToken);
      setAnnouncements(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch announcements');
      console.error('Error fetching announcements:', err);
    } finally {
      setLoading(false);
    }
  }, [accessToken, isAuthenticated]);

  const createAnnouncement = useCallback(async (announcement: AnnouncementCreate) => {
    if (!accessToken) {
      throw new Error('No access token');
    }

    try {
      const newAnnouncement = await announcementsService.create(
        accessToken,
        announcement
      );
      setAnnouncements((prev) => [newAnnouncement, ...prev]);
      return newAnnouncement;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create announcement';
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  }, [accessToken]);

  const updateAnnouncement = useCallback(async (id: number, announcement: AnnouncementUpdate) => {
    if (!accessToken) {
      throw new Error('No access token');
    }

    try {
      await announcementsService.update(accessToken, id, announcement);
      await fetchAnnouncements();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to update announcement';
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  }, [accessToken, fetchAnnouncements]);

  const deleteAnnouncement = useCallback(async (id: number) => {
    if (!accessToken) {
      throw new Error('No access token');
    }

    try {
      await announcementsService.delete(accessToken, id);
      setAnnouncements((prev) => prev.filter((a) => a.id !== id));
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to delete announcement';
      setError(errorMessage);
      throw new Error(errorMessage);
    }
  }, [accessToken]);

  useEffect(() => {
    fetchAnnouncements();
  }, [fetchAnnouncements]);

  return {
    announcements,
    loading,
    error,
    refetch: fetchAnnouncements,
    createAnnouncement,
    updateAnnouncement,
    deleteAnnouncement,
  };
}

