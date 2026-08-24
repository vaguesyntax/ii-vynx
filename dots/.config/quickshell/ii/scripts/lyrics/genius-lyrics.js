// genius-lyrics.js
import pkg from 'genius-lyrics-api';
const { getLyrics, getSong } = pkg;  // fetchLyrics/fetchSong değil, pkg içinden alıyoruz

// kendi async wrapper fonksiyonlarımız
export async function fetchLyrics(apiKey, title, artist) {
    // Keeping the artist in the query is important; the package's optimizer can rank unrelated songs first.
    const options = { apiKey, title, artist, optimizeQuery: false };
    try {
        return await getLyrics(options);
    } catch (err) {
        console.error("Lyrics fetch error:", err);
        return null;
    }
}

export async function fetchSong(apiKey, title, artist) {
    // Keeping the artist in the query is important; the package's optimizer can rank unrelated songs first.
    const options = { apiKey, title, artist, optimizeQuery: false };
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

// CLI çalıştırma kısmı
// The shell calls this as: <api-key> <artist> <title>.
const [,, apiKey, artistName, songTitle] = process.argv;

if (apiKey && songTitle && artistName) {
    (async () => {
        const song = await fetchSong(apiKey, songTitle, artistName);
        if (!song) {
            console.log("Song not found.");
            return;
        }
        console.log(song.lyrics);
    })();
}