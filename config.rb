MEDIA_ROOT = '/bulk'
EXCLUDE    = ['/bulk/downloads']

COMMIT_ID   = `git log -n1 --oneline | cut -f1 -d\\ `
MEDIA_EXTENSIONS  = /\.(mp3|ape|flac|ogg|mkv|avi|wmv|iso)$/i
IGNORE_EXTENSIONS = /\.(nfo|tbn)$/i
REPO_PATH        = 'sqlite:/home/xuser/gulaplex/gulaplex.db'
