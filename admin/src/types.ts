export interface User {
  id: string;
  username: string;
  avatar: string;
  bio?: string;
  followersCount: number;
  level: number;
  coins: number;
}

export interface Song {
  id: string;
  title: string;
  artist: string;
  audioUrl: string; // URL to backing track
  lrcUrl?: string;   // URL to LRC lyrics file
  lyrics?: { time: number; text: string }[];
  coverUrl: string;
  genre: string;
  playCount: number;
}

export interface Recording {
  id: string;
  userId: string;
  songId: string;
  audioUrl?: string;
  coverUrl?: string;
  caption?: string;
  visibility?: 'Public' | 'Private' | string;
  videoUrl?: string;
  score: number;
  duetParentId?: string;
  createdAt: string;
  user?: User;
  song?: Song;
  likesCount: number;
  commentsCount: number;
}
