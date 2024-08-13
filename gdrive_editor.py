from pydrive2.fs import GDriveFileSystem
from pydrive2.auth import GoogleAuth

gauth = GoogleAuth()
gauth.LoadServiceConfigSettings("docker/houdini-vastai-431918-2ccc7659a237.json")
