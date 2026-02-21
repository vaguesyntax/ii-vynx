import { getLyrics, getSong } from 'genius-lyrics-api';

let apiKey = '';

export function init(key) {
    apiKey = key;
}


export async function fetchLyrics(title, artist) {
    if (!apiKey) throw new Error("API key was not initialized!");
    
    const options = {
        apiKey,
        title,
        artist,
        optimizeQuery: true
    };

    try {
        const lyrics = await getLyrics(options);
        return lyrics;
    } catch (err) {
        console.error("Lyrics fetch error:", err);
        return null;
    }
}

export async function fetchSong(title, artist) {
    if (!apiKey) throw new Error("API key was not initialized!");
    
    const options = {
        apiKey,
        title,
        artist,
        optimizeQuery: true
    };

    try {
        const song = await getSong(options);
        if (!song) return null;

        return {
            id: song.id,
            title: song.title,
            url: song.url,
            albumArt: song.albumArt,
            lyrics: song.lyrics
        };
    } catch (err) {
        console.error("Song fetch error:", err);
        return null;
    }
}