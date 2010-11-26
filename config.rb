MEDIA_ROOT = '/media'
EXCLUDE    = ['/media/downloads']

COMMIT_ID   = `git log -n1 --oneline | cut -f1 -d\\ `
MEDIA_EXTENSIONS = /(mp3|ape|flac|mkv|avi|wmv|iso)$/i
REPO_PATH        = 'sqlite3:/tmp/test.db'
