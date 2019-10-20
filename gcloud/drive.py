from __future__ import print_function
import datetime
import httplib2
import os

from apiclient import discovery
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage

from googleapiclient.http import MediaFileUpload

try:
    import argparse
    flags = argparse.ArgumentParser(parents=[tools.argparser]).parse_args()
except ImportError:
    flags = None

# If modifying these scopes, delete your previously saved credentials
# at ~/.credentials/drive-python.json
SCOPES = 'https://www.googleapis.com/auth/drive'
CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'Drive API Python Quickstart'


def get_credentials():
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """
    home_dir = os.path.expanduser('~')
    credential_dir = os.path.join(home_dir, '.credentials')
    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)
    credential_path = os.path.join(credential_dir,
                                   'drive-python.json')

    store = Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = tools.run_flow(flow, store, flags)
        else: # Needed only for compatibility with Python 2.6
            credentials = tools.run(flow, store)
        print('Storing credentials to ' + credential_path)
    return credentials

def main():
    """Shows basic usage of the Google Drive API.

    Creates a Google Drive API service object and outputs the names and IDs
    for up to 10 files.
    """
    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    service = discovery.build('drive', 'v3', http=http)

    results = service.files().list(
        pageSize=10,fields="nextPageToken, files(id, name, md5Checksum, size)").execute()
    items = results.get('files', [])
    if not items:
        print('No files found.')
    else:
        print('Files:')
        for item in items:
            print('{2} {0} {1} {3}'.format(item['name'],
                                       item['id'],
                                       item.get('md5Checksum', 'no checksum'),
                                       item.get('size', '-')))
    return service

def mod_time(fname):
    return (datetime.datetime(1970, 1, 1) +
                         datetime.timedelta(microseconds=os.stat(fname).st_mtime_ns // 1000)).strftime(
                             '%Y-%m-%dT%H:%M:%S.%f+00:00')

def upload(service, fname, parent_id=None):
    file_metadata={
        'name': os.path.basename(fname),
        'modifiedTime': mod_time(fname),
    }
    if parent_id is not None:
        file_metadata['parents'] = [parent_id]
    media = MediaFileUpload(fname)  #, mimetype='application/octet-stream')
    f = service.files().create(body=file_metadata, media_body=media, fields='md5Checksum, id').execute()
    print('uploaded', fname)
    #f.get('id')
    #u'15FTcr9i1VHW4UgWhk4hn5W5Joe-ww7U3'
    return f

def upload_dir(service, dname, parent_id=None):
    ids = {dname: parent_id}
    for d, dirs, files in os.walk(dname):
        pid = ids[d]
        p = {} if pid is None else {'parents': [pid]}
        for dname in dirs:
            fdname = '{}/{}'.format(d, dname)
            body = {'name': dname, 'modifiedTime': mod_time(fdname), 'mimeType': 'application/vnd.google-apps.folder'}
            body.update(p)
            ids[fdname] = service.files().create(body=body, fields='id').execute().get('id')
        for fname in files:
            upload(service, '{}/{}'.format(d, fname), pid)

if __name__ == '__main__':
    service = main()
    upload_dir(service, 'ls', '1t6bdkHYAGcsIB87yNs2bVUcjbg9n7lyz')
