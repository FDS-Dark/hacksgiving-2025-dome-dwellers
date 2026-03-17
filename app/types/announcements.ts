export interface Announcement {
  id: number;
  title: string;
  message: string;
  author_id: number;
  author_name: string;
  author_email?: string;
  created_at: string;
  updated_at: string;
}

export interface AnnouncementCreate {
  title: string;
  message: string;
}

export interface AnnouncementUpdate {
  title: string;
  message: string;
}

